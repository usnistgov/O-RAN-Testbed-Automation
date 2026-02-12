// NIST-developed software is provided by NIST as a public service. You may use,
// copy, and distribute copies of the software in any medium, provided that you
// keep intact this entire notice. You may improve, modify, and create derivative
// works of the software or any portion of the software, and you may copy and
// distribute such modifications or works. Modified works should carry a notice
// stating that you changed the software and should note the date and nature of
// any such change. Please explicitly acknowledge the National Institute of
// Standards and Technology as the source of the software.
//
// NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
// OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
// INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
// NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
// UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
// NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
// THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
// RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
//
// You are solely responsible for determining the appropriateness of using and
// distributing the software and you assume all risks associated with its use,
// including but not limited to the risks and costs of program errors, compliance
// with applicable laws, damage to or loss of data, programs or equipment, and
// the unavailability or interruption of operation. This software is not intended
// to be used in any situation where a failure could cause risk of injury or
// damage to property. The software developed by NIST employees is not subject to
// copyright protection within the United States.

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/util/alg_ds/alg/defer.h"
#include "../../../../src/util/time_now_us.h"
#include "../../../../src/util/alg_ds/alg/murmur_hash_32.h"
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"
#include "../../../../src/util/alg_ds/ds/assoc_container/assoc_generic.h"
#include "../../../../src/util/e.h"

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <inttypes.h>
#include <math.h>

// Set to the interval in milliseconds at which the xApp should write to the CSV file
static
uint64_t period_ms = 1000;

// Lowering the timestamp precision groups measurements from multiple UEs under the same timestamp, making it easier to identify simultaneous connections.
uint64_t timestamp_precision = 10;

// For metrics based on the difference between indication messages, the first sample may give a wrong value, so it is skipped.
bool skip_first_sample = true;

// Set to true if samples containing RSRP.Count == 0 are to be filtered,
// which is expected to give more stable results at the expense of some data loss
const bool filter_invalid_rsrp_samples = false;

static
pthread_mutex_t mtx;

static
assoc_ht_open_t ht = {0};

// Overwritten if environment variables SST and SD are set
static
uint8_t  cfg_slicing_sst = 1;
static
uint32_t cfg_slicing_sd  = 0xFFFFFF; // 0xFFFFFF for any SD

// Configurations for InfluxDB
bool clear_database_on_startup = true;
char influxdb_url[256] = "http://localhost:8086";
char influxdb_org[64] = "xapp-kpm-moni";
char influxdb_bucket[64] = "xapp-kpm-moni";
char influxdb_token[128]; // Input argument: argv[1]

// Variables that change during runtime
char influx_fields_buffer[2048];
unsigned int influx_num_samples = 0;
uint64_t current_ue_id = 0;
bool filter_current_sample = false;
int64_t prev_now = 0;

// Buffer to store the current E2 Node ID
static
char current_e2_id_str[256];

static
uint32_t hash_func(const void* key_v)
{
  char* key = *(char**)(key_v);
  static const uint32_t seed = 42;
  return murmur3_32((uint8_t*)key, strlen(key), seed);
}

static
bool cmp_str(const void* a, const void* b)
{
  char* a_str = *(char**)(a);
  char* b_str = *(char**)(b);

  int const ret = strcmp(a_str, b_str);
  return ret == 0;
}

static
void free_str(void* key, void* value)
{
  free(*(char**)key);
  free(value);
}

static
void free_kpm_meas_unit_hash_table(void)
{
  assoc_ht_open_free(&ht);
}

static
void init_kpm_meas_unit_hash_table(void)
{
  FILE *fp = fopen(KPM_MEAS_LIST, "r");
  if (!fp) {
    printf("Cannot open the file \"%s\".\n", KPM_MEAS_LIST);
    perror("Error");
    return;
  }

  assoc_ht_open_init(&ht, sizeof(char*), cmp_str, free_str, hash_func);
  char line[128];
  while (fgets(line, sizeof(line), fp)) {
    char *col1, *col2;
    sscanf(line, "%ms %ms", &col1, &col2);
    assoc_ht_open_insert(&ht, &col1, sizeof(char*), col2);
  }
  fclose(fp);
}

static
char *get_meas_unit(const char *name)
{
  return assoc_ht_open_value(&ht, &name);
}

static
bool sanitize_metric_name(const char *name, char *out, size_t out_size) {
  size_t j = 0;
  size_t name_len = strlen(name);
  for (size_t i = 0; i < name_len && j < out_size - 1; i++) {
    char c = name[i];
    if ((c >= 'A' && c <= 'Z') ||
        (c >= 'a' && c <= 'z') ||
        (c >= '0' && c <= '9') ||
        c == '_' || c == '.') {
      out[j++] = c;
    }
  }
  out[j] = '\0';
  return j > 0;
}

void reset_measurement_buffers() {
  memset(influx_fields_buffer, 0, sizeof(influx_fields_buffer));
}

void influxdb_clear_bucket() {
  char cmd[2048];
  char current_time_iso[64];

  // Get current time in ISO 8601 format (UTC)
  time_t now = time(NULL);
  struct tm *utc_time = gmtime(&now);
  strftime(current_time_iso, sizeof(current_time_iso), "%Y-%m-%dT%H:%M:%SZ", utc_time);

  snprintf(cmd, sizeof(cmd),
           "curl --request POST '%s/api/v2/delete?org=%s&bucket=%s' "
           "--header 'Authorization: Token %s' "
           "--header 'Content-Type: application/json' "
           "--data '{\"start\":\"1970-01-01T00:00:00Z\",\"stop\":\"%s\"}' || echo 'InfluxDB delete failed'",
           influxdb_url, influxdb_org, influxdb_bucket, influxdb_token, current_time_iso);

  printf("Clearing InfluxDB data from previous runs...\n");
  system(cmd);
  printf("InfluxDB data cleared successfully up to %s.\n", current_time_iso);
}

void influxdb_write(char *line_protocol) {
  char cmd[2048];

  snprintf(cmd, sizeof(cmd),
           "curl -XPOST '%s/api/v2/write?org=%s&bucket=%s&precision=ms' "
           "--header 'Authorization: Token %s' "
           "--data-raw '%s' || echo 'InfluxDB write failed'",
           influxdb_url, influxdb_org, influxdb_bucket, influxdb_token, line_protocol);

  system(cmd);
}

// At the end of the measurement cycle, send the metrics to InfluxDB
void send_metrics_to_influxdb(uint64_t ue_id, const char *e2_node_id, int64_t timestamp_ms, char *fields_buffer) {
  char line_protocol[1024];
  // Ensure there's a trailing comma if not already present
  size_t len = strlen(fields_buffer);
  if (len > 0 && fields_buffer[len - 1] != ',') {
    strcat(fields_buffer, ",");
  }

  // Round down the timestamp to the nearest multiple of timestamp_precision
  timestamp_ms = timestamp_ms - (timestamp_ms % timestamp_precision);

  // Construct Line Protocol (measurement: kpm_measurements)
  snprintf(line_protocol, sizeof(line_protocol),
           "kpm_measurements %sE2_NODE_ID=\"%s\",UE_ID=%" PRIu64 "i %ld",
           fields_buffer, e2_node_id, ue_id, timestamp_ms);

  // printf("Metrics for UE ID %" PRIu64 " (E2 Node: %s): %s (timestamp: %ld ms)\n", ue_id, e2_node_id, fields_buffer, timestamp_ms);

  // Send metrics to InfluxDB
  influxdb_write(line_protocol);
}

static
void log_gnb_ue_id(ue_id_e2sm_t ue_id)
{
  if (ue_id.gnb.gnb_cu_ue_f1ap_lst != NULL) {
    for (size_t i = 0; i < ue_id.gnb.gnb_cu_ue_f1ap_lst_len; i++) {
      printf("UE ID type = gNB-CU, gnb_cu_ue_f1ap = %u\n", ue_id.gnb.gnb_cu_ue_f1ap_lst[i]);
    }
  } else {
    printf("UE ID type = gNB, amf_ue_ngap_id = %lu\n", ue_id.gnb.amf_ue_ngap_id);
  }
  if (ue_id.gnb.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb.ran_ue_id); // RAN UE NGAP ID
  }
  current_ue_id = ue_id.gnb.amf_ue_ngap_id; // Update the global UE ID

  // Store the current E2 Node ID (prefer Global NG-RAN Node ID, then Global gNB ID, then CU F1AP ID)
  if (ue_id.gnb.global_ng_ran_node_id) {
    const global_ng_ran_node_id_t *n = ue_id.gnb.global_ng_ran_node_id;
    switch (n->type) {
      case GNB_GLOBAL_TYPE_ID: {
        const global_gnb_id_t *g = &n->global_gnb_id;
        if (g->type == GNB_TYPE_ID) {
          snprintf(current_e2_id_str, sizeof(current_e2_id_str), "gNB:%u", (unsigned)g->gnb_id.nb_id);
        } else {
          snprintf(current_e2_id_str, sizeof(current_e2_id_str), "gNB:UNKNOWN");
        }
        break;
      }
      case NG_ENB_GLOBAL_TYPE_ID: {
        const global_ng_enb_id_t *e = &n->global_ng_enb_id;
        switch (e->type) {
          case MACRO_NG_ENB_TYPE_ID:
            snprintf(current_e2_id_str, sizeof(current_e2_id_str), "ng-eNB-macro:%u", (unsigned)e->macro_ng_enb_id);
            break;
          case SHORT_MACRO_NG_ENB_TYPE_ID:
            snprintf(current_e2_id_str, sizeof(current_e2_id_str), "ng-eNB-short:%u", (unsigned)e->short_macro_ng_enb_id);
            break;
          case LONG_MACRO_NG_ENB_TYPE_ID:
            snprintf(current_e2_id_str, sizeof(current_e2_id_str), "ng-eNB-long:%u", (unsigned)e->long_macro_ng_enb_id);
            break;
          default:
            snprintf(current_e2_id_str, sizeof(current_e2_id_str), "ng-eNB:unsupported:%d", (int)e->type);
            break;
        }
        break;
      }
      default:
        snprintf(current_e2_id_str, sizeof(current_e2_id_str), "UNKNOWN");
        break;
    }
  } else if (ue_id.gnb.global_gnb_id) {
    snprintf(current_e2_id_str, sizeof(current_e2_id_str), "gNB:%u", (unsigned)ue_id.gnb.global_gnb_id->gnb_id.nb_id);
  } else if (ue_id.gnb.gnb_cu_ue_f1ap_lst && ue_id.gnb.gnb_cu_ue_f1ap_lst_len > 0) {
    snprintf(current_e2_id_str, sizeof(current_e2_id_str), "CU:%u", (unsigned)ue_id.gnb.gnb_cu_ue_f1ap_lst[0]);
  } else {
    snprintf(current_e2_id_str, sizeof(current_e2_id_str), "gNB");
  }
}

static
void log_du_ue_id(ue_id_e2sm_t ue_id)
{
  printf("UE ID type = gNB-DU, gnb_cu_ue_f1ap = %u\n", ue_id.gnb_du.gnb_cu_ue_f1ap);
  if (ue_id.gnb_du.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb_du.ran_ue_id); // RAN UE NGAP ID
  }
  current_ue_id = ue_id.gnb_du.gnb_cu_ue_f1ap; // Update the global UE ID

  // Store the current E2 Node ID
  snprintf(current_e2_id_str, sizeof(current_e2_id_str), "DU:%u", ue_id.gnb_du.gnb_cu_ue_f1ap);
}

static
void log_cuup_ue_id(ue_id_e2sm_t ue_id)
{
  printf("UE ID type = gNB-CU-UP, gnb_cu_cp_ue_e1ap = %u\n", ue_id.gnb_cu_up.gnb_cu_cp_ue_e1ap);
  if (ue_id.gnb_cu_up.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb_cu_up.ran_ue_id); // RAN UE NGAP ID
  }
  current_ue_id = ue_id.gnb_cu_up.gnb_cu_cp_ue_e1ap; // Update the global UE ID

  // Store the current E2 Node ID
  snprintf(current_e2_id_str, sizeof(current_e2_id_str), "CU-UP:%u", ue_id.gnb_cu_up.gnb_cu_cp_ue_e1ap);
}

typedef void (*log_ue_id)(ue_id_e2sm_t ue_id);

static
log_ue_id log_ue_id_e2sm[END_UE_ID_E2SM] = {
    log_gnb_ue_id, // common for gNB-mono, CU and CU-CP
    log_du_ue_id,
    log_cuup_ue_id,
    NULL,
    NULL,
    NULL,
    NULL,
};

static
void log_int_value(const char *name_str, const label_info_lst_t label_info, const meas_record_lst_t meas_record)
{
  (void)label_info;
  char *name_unit = get_meas_unit(name_str);
  if (name_unit && strcmp(name_unit, "[]") == 0) name_unit = "";
  if (name_unit == NULL) name_unit = "";

  char safe_metric_name[128];
  if (!sanitize_metric_name(name_str, safe_metric_name, sizeof(safe_metric_name))) {
    fprintf(stderr, "Invalid metric name detected.\n");
    return;
  }

  char influx_field_name[256];
  
  // Format unit
  char clean_unit[64];
  size_t unit_len = strlen(name_unit);
  if (unit_len > 2 && name_unit[0] == '[' && name_unit[unit_len - 1] == ']') {
    snprintf(clean_unit, sizeof(clean_unit), "%.*s", (int)(unit_len - 2), name_unit + 1);
    unit_len -= 2;
  } else {
    snprintf(clean_unit, sizeof(clean_unit), "%s", name_unit);
  }

  if (unit_len > 0) {
    snprintf(influx_field_name, sizeof(influx_field_name), "%s_%s", safe_metric_name, clean_unit);
  } else {
    snprintf(influx_field_name, sizeof(influx_field_name), "%s", safe_metric_name);
  }

  char influx_field[512];
  snprintf(influx_field, sizeof(influx_field), "%s=%di,", influx_field_name, meas_record.int_val);
  strncat(influx_fields_buffer, influx_field, sizeof(influx_fields_buffer) - strlen(influx_fields_buffer) - 1);

  // If the measurement is RSRP.Count and the value is 0, the data is invalid
  if (filter_invalid_rsrp_samples && strcmp("RSRP.Count", name_str) == 0) {
    if (meas_record.int_val == 0) {
      filter_current_sample = true;
      // printf("\n\tNumber of RSRP measurements was zero, skipping sample to avoid divide by zero.\n\n");
    }
  }
}

static
void log_real_value(const char *name_str, const label_info_lst_t label_info, const meas_record_lst_t meas_record)
{
  (void)label_info;
  char *name_unit = get_meas_unit(name_str);
  if (name_unit && strcmp(name_unit, "[]") == 0) name_unit = "";
  if (name_unit == NULL) name_unit = "";

  char safe_metric_name[128];
  if (!sanitize_metric_name(name_str, safe_metric_name, sizeof(safe_metric_name))) {
    fprintf(stderr, "Invalid metric name detected.\n");
    return;
  }

  char influx_field_name[256];
  char clean_unit[64];
  size_t unit_len = strlen(name_unit);
  if (unit_len > 2 && name_unit[0] == '[' && name_unit[unit_len - 1] == ']') {
    snprintf(clean_unit, sizeof(clean_unit), "%.*s", (int)(unit_len - 2), name_unit + 1);
    unit_len -= 2;
  } else {
    snprintf(clean_unit, sizeof(clean_unit), "%s", name_unit);
  }

  if (unit_len > 0) {
    snprintf(influx_field_name, sizeof(influx_field_name), "%s_%s", safe_metric_name, clean_unit);
  } else {
    snprintf(influx_field_name, sizeof(influx_field_name), "%s", safe_metric_name);
  }

  // Check for NaN
  if (!isnan(meas_record.real_val)) {
    char influx_field[512];
    snprintf(influx_field, sizeof(influx_field), "%s=%.2f,", influx_field_name, meas_record.real_val);
    strncat(influx_fields_buffer, influx_field, sizeof(influx_fields_buffer) - strlen(influx_fields_buffer) - 1);
  }
}

typedef void (*log_meas_value)(const char *name_str, const label_info_lst_t label_info, const meas_record_lst_t meas_record);

static
log_meas_value get_meas_value[END_MEAS_VALUE] = {
    log_int_value,
    log_real_value,
    NULL,
};

static
void match_meas_name_type(const meas_type_t meas_type, const label_info_lst_t label_info, const meas_record_lst_t record_item)
{
  // Get the value of the Measurement
  char *name_str = cp_ba_to_str(meas_type.name);
  get_meas_value[record_item.value](name_str, label_info, record_item);
  free(name_str);
}

static
void match_id_meas_type(const meas_type_t meas_type, const label_info_lst_t label_info, const meas_record_lst_t record_item)
{
  (void)meas_type;
  (void)label_info;
  (void)record_item;
  assert(false && "ID Measurement Type not yet supported");
}

typedef void (*check_meas_type)(const meas_type_t meas_type, const label_info_lst_t label_info, const meas_record_lst_t meas_record);

static
check_meas_type match_meas_type[END_MEAS_TYPE] = {
    match_meas_name_type,
    match_id_meas_type,
};

static
void log_kpm_measurements(kpm_ind_msg_format_1_t const* msg_frm_1)
{
  assert(msg_frm_1->meas_info_lst_len > 0 && "Cannot correctly print measurements");

  // printf("Current E2 Node ID: %s\n", current_e2_id_str);

  reset_measurement_buffers(); // Start new line protocol

  // UE Measurements per granularity period
  for (size_t j = 0; j < msg_frm_1->meas_data_lst_len; j++) {
    meas_data_lst_t const data_item = msg_frm_1->meas_data_lst[j];

    for (size_t i = 0; i < msg_frm_1->meas_info_lst_len; i++) {
        const meas_info_format_1_lst_t info_item = msg_frm_1->meas_info_lst[i];
        for (size_t z = 0; z < info_item.label_info_lst_len; z++) {
          const label_info_lst_t label_info = info_item.label_info_lst[z];
          const meas_record_lst_t record_item = data_item.meas_record_lst[i + z];

          match_meas_type[info_item.meas_type.type](info_item.meas_type, label_info, record_item);
        }
    }
  }

  if (skip_first_sample) {
    printf("Skipping first sample to avoid incorrect initial values.\n");
    reset_measurement_buffers();
    skip_first_sample = false;
    return;
  }

  if (filter_invalid_rsrp_samples || !filter_current_sample) {
    // Send to InfluxDB
    int64_t now_ms = time_now_us() / 1000;
    send_metrics_to_influxdb(current_ue_id, current_e2_id_str, now_ms, influx_fields_buffer);
  }

  filter_current_sample = false;
  influx_num_samples++;
  printf("Samples collected = %u\n", influx_num_samples);
}

static
void log_kpm_ind_msg_frm_3(kpm_ind_msg_format_3_t const* msg)
{
  // Reported list of measurements per UE
  for (size_t i = 0; i < msg->ue_meas_report_lst_len; i++) {
    // log UE ID
    ue_id_e2sm_t const ue_id_e2sm = msg->meas_report_per_ue[i].ue_meas_report_lst;
    ue_id_e2sm_e const type = ue_id_e2sm.type;
    log_ue_id_e2sm[type](ue_id_e2sm);

    // log measurements
    log_kpm_measurements(&msg->meas_report_per_ue[i].ind_msg_format_1);
  }
}

static
void load_slice_from_env(void)
{
  const char *s;
  char *end = NULL;
  errno = 0;

  s = getenv("SST");
  if (s && *s) {
    unsigned long v = strtoul(s, &end, 0);
    if (end != s && errno == 0 && v <= 0xFFul) cfg_slicing_sst = (uint8_t)v;
  }

  errno = 0; end = NULL;
  s = getenv("SD");
  if (s && *s) {
    unsigned long v = strtoul(s, &end, 0);
    if (end != s && errno == 0) cfg_slicing_sd = ((uint32_t)v) & 0xFFFFFFu;
  }

  printf("[xApp] Using S-NSSAI SST=%u SD=%06x (env SST/SD can override)\n", (unsigned)cfg_slicing_sst, (unsigned)(cfg_slicing_sd & 0xFFFFFFu));
}

static
void sm_cb_kpm(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0);

  // Reading Indication Message Format 3
  kpm_ind_data_t const* ind = &rd->ind.kpm.ind;
  kpm_ric_ind_hdr_format_1_t const* hdr_frm_1 = &ind->hdr.kpm_ric_ind_hdr_format_1;

  int64_t const now = time_now_us();
  static int counter = 1;
  {
    lock_guard(&mtx);

    printf("\n%7d KPM ind_msg latency = %ld [μs]\n", counter, now - hdr_frm_1->collectStartTime); // xApp <-> E2 Node

    if (ind->msg.type == FORMAT_1_INDICATION_MESSAGE) {
      log_kpm_measurements(&ind->msg.frm_1);
    } else if (ind->msg.type == FORMAT_3_INDICATION_MESSAGE) {
      log_kpm_ind_msg_frm_3(&ind->msg.frm_3);
    } else {
      printf("KPM Indication Message %d logging not yet implemented.\n", ind->msg.type);
    }
    counter++;
  }
  prev_now = now / 1000;
}

static
test_info_lst_t filter_predicate(test_cond_type_e type, test_cond_e cond, uint8_t sst, uint32_t sd)
{
  test_info_lst_t dst = {0};

  dst.test_cond_type = type;
  // It can only be TRUE_TEST_COND_TYPE so it does not matter the type
  // but ugly ugly...
  dst.S_NSSAI = TRUE_TEST_COND_TYPE;

  dst.test_cond = calloc(1, sizeof(test_cond_e));
  assert(dst.test_cond != NULL && "Memory exhausted");
  *dst.test_cond = cond;

  dst.test_cond_value = calloc(1, sizeof(test_cond_value_t));
  assert(dst.test_cond_value != NULL && "Memory exhausted");
  dst.test_cond_value->type = OCTET_STRING_TEST_COND_VALUE;

  dst.test_cond_value->octet_string_value = calloc(1, sizeof(byte_array_t));
  assert(dst.test_cond_value->octet_string_value != NULL && "Memory exhausted");
  const size_t len_nssai = (sd == 0xFFFFFF) ? 1 : 4;
  dst.test_cond_value->octet_string_value->len = len_nssai;
  dst.test_cond_value->octet_string_value->buf = calloc(len_nssai, sizeof(uint8_t));
  assert(dst.test_cond_value->octet_string_value->buf != NULL && "Memory exhausted");
  dst.test_cond_value->octet_string_value->buf[0] = (uint8_t)sst;
  if (len_nssai == 4) {
    sd &= 0xFFFFFF;
    dst.test_cond_value->octet_string_value->buf[1] = (uint8_t)((sd >> 16) & 0xFF);
    dst.test_cond_value->octet_string_value->buf[2] = (uint8_t)((sd >> 8) & 0xFF);
    dst.test_cond_value->octet_string_value->buf[3] = (uint8_t)(sd & 0xFF);
  }

  return dst;
}

static
label_info_lst_t fill_kpm_label(void)
{
  label_info_lst_t label_item = {0};

  label_item.noLabel = ecalloc(1, sizeof(enum_value_e));
  *label_item.noLabel = TRUE_ENUM_VALUE;

  return label_item;
}

static
kpm_act_def_format_1_t fill_act_def_frm_1(ric_report_style_item_t const* report_item)
{
  assert(report_item != NULL);

  kpm_act_def_format_1_t ad_frm_1 = {0};

  size_t const sz = report_item->meas_info_for_action_lst_len;

  // [1, 65535]
  ad_frm_1.meas_info_lst_len = sz;
  ad_frm_1.meas_info_lst = calloc(sz, sizeof(meas_info_format_1_lst_t));
  assert(ad_frm_1.meas_info_lst != NULL && "Memory exhausted");

  for (size_t i = 0; i < sz; i++) {
    meas_info_format_1_lst_t* meas_item = &ad_frm_1.meas_info_lst[i];
    // 8.3.9
    // Measurement Name
    meas_item->meas_type.type = NAME_MEAS_TYPE;
    meas_item->meas_type.name = copy_byte_array(report_item->meas_info_for_action_lst[i].name);

    // [1, 2147483647]
    // 8.3.11
    meas_item->label_info_lst_len = 1;
    meas_item->label_info_lst = ecalloc(1, sizeof(label_info_lst_t));
    meas_item->label_info_lst[0] = fill_kpm_label();
  }

  // 8.3.8 [0, 4294967295]
  ad_frm_1.gran_period_ms = period_ms;

  // 8.3.20 - OPTIONAL
  ad_frm_1.cell_global_id = NULL;

#if defined KPM_V2_03 || defined KPM_V3_00
  // [0, 65535]
  ad_frm_1.meas_bin_range_info_lst_len = 0;
  ad_frm_1.meas_bin_info_lst = NULL;
#endif

  return ad_frm_1;
}

static
kpm_act_def_t fill_report_style_4(ric_report_style_item_t const* report_item)
{
  assert(report_item != NULL);
  assert(report_item->act_def_format_type == FORMAT_4_ACTION_DEFINITION);

  kpm_act_def_t act_def = {.type = FORMAT_4_ACTION_DEFINITION};

  // Filter connected UEs by S-NSSAI criteria
  test_cond_type_e const type = S_NSSAI_TEST_COND_TYPE; // CQI_TEST_COND_TYPE
  test_cond_e const condition = EQUAL_TEST_COND; // GREATERTHAN_TEST_COND

  // Fill matching condition
  // [1, 32768]
  act_def.frm_4.matching_cond_lst_len = 1;
  act_def.frm_4.matching_cond_lst = calloc(1, sizeof(*act_def.frm_4.matching_cond_lst));
  assert(act_def.frm_4.matching_cond_lst != NULL && "Memory exhausted");
  act_def.frm_4.matching_cond_lst[0].test_info_lst = filter_predicate(type, condition, cfg_slicing_sst, cfg_slicing_sd);

  // Fill Action Definition Format 1
  // 8.2.1.2.1
  act_def.frm_4.action_def_format_1 = fill_act_def_frm_1(report_item);

  return act_def;
}

static
label_info_lst_t fill_distribution_bin_label(const uint32_t x, const uint32_t y, const uint32_t z)
{
  label_info_lst_t label_item = {0};

  label_item.distBinX = calloc(1, sizeof(uint32_t));
  assert(label_item.distBinX != NULL);
  *label_item.distBinX = x;

  label_item.distBinY = calloc(1, sizeof(uint32_t));
  assert(label_item.distBinY != NULL);
  *label_item.distBinY = y;

  label_item.distBinZ = calloc(1, sizeof(uint32_t));
  assert(label_item.distBinZ != NULL);
  *label_item.distBinZ = z;

  return label_item;
}

static
kpm_act_def_t fill_report_style_1(ric_report_style_item_t const* report_item)
{
  assert(report_item != NULL);
  assert(report_item->act_def_format_type == FORMAT_1_ACTION_DEFINITION);

  kpm_act_def_t act_def = {.type = FORMAT_1_ACTION_DEFINITION};

  // [1, 65535]
  act_def.frm_1.meas_info_lst_len = report_item->meas_info_for_action_lst_len;
  act_def.frm_1.meas_info_lst = ecalloc(act_def.frm_1.meas_info_lst_len, sizeof(meas_info_format_1_lst_t));
  for (size_t i = 0; i < act_def.frm_1.meas_info_lst_len; i++) {
    meas_info_format_1_lst_t* meas_item = &act_def.frm_1.meas_info_lst[i];
    // 8.3.9
    // Measurement Name
    meas_item->meas_type.type = NAME_MEAS_TYPE;
    meas_item->meas_type.name = copy_byte_array(report_item->meas_info_for_action_lst[i].name);

    // [1, 2147483647]
    // 8.3.11
    if (cmp_str_ba("CARR.PDSCHMCSDist", meas_item->meas_type.name) == 0) {
      /// 1-8 RI, 1-3 MCS table, 0-31 MCS value
      meas_item->label_info_lst_len = 8 * 3 * 32;
      meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
      size_t idx = 0;
      for (uint32_t x = 1; x <= 8; x++) {
        for (uint32_t y = 1; y <= 3; y++) {
          for(uint32_t z = 0; z <= 31; z++) {
            meas_item->label_info_lst[idx++] = fill_distribution_bin_label(x, y, z);
          }
        }
      }
    } else {
      meas_item->label_info_lst_len = 1;
      meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
      meas_item->label_info_lst[0] = fill_kpm_label();
    }
  }

  // 8.3.8 [0, 4294967295]
  act_def.frm_1.gran_period_ms = period_ms;

  // 8.3.20 - OPTIONAL
  act_def.frm_1.cell_global_id = NULL;

#if defined KPM_V2_03 || defined KPM_V3_00
  // [0, 65535]
  act_def.frm_1.meas_bin_range_info_lst_len = 0;
  act_def.frm_1.meas_bin_info_lst = NULL;
#endif

  return act_def;
}

typedef kpm_act_def_t (*fill_kpm_act_def)(ric_report_style_item_t const* report_item);

static
fill_kpm_act_def get_kpm_act_def[END_RIC_SERVICE_REPORT] = {
    fill_report_style_1,
    NULL,
    NULL,
    fill_report_style_4,
    NULL,
};

static
kpm_sub_data_t gen_kpm_subs(kpm_ran_function_def_t const* ran_func, ric_report_style_item_t const* report_item)
{
  assert(ran_func != NULL);
  assert(ran_func->ric_event_trigger_style_list != NULL);

  kpm_sub_data_t kpm_sub = {0};

  // Generate Event Trigger
  assert(ran_func->ric_event_trigger_style_list[0].format_type == FORMAT_1_RIC_EVENT_TRIGGER);
  kpm_sub.ev_trg_def.type = FORMAT_1_RIC_EVENT_TRIGGER;
  kpm_sub.ev_trg_def.kpm_ric_event_trigger_format_1.report_period_ms = period_ms;

  // Generate Action Definition
  kpm_sub.sz_ad = 1;
  kpm_sub.ad = calloc(kpm_sub.sz_ad, sizeof(kpm_act_def_t));
  assert(kpm_sub.ad != NULL && "Memory exhausted");

  // Multiple Action Definitions in one SUBSCRIPTION message is not supported in this project
  // Multiple REPORT Styles = Multiple Action Definition = Multiple SUBSCRIPTION messages
  ric_service_report_e const report_style_type = report_item->report_style_type;
  *kpm_sub.ad = get_kpm_act_def[report_style_type](report_item);

  return kpm_sub;
}

static
bool eq_sm(sm_ran_function_t const* elem, int const id)
{
  if (elem->id == id)
    return true;

  return false;
}

static
size_t find_sm_idx(sm_ran_function_t* rf, size_t sz, bool (*f)(sm_ran_function_t const*, int const), int const id)
{
  for (size_t i = 0; i < sz; i++) {
    if (f(&rf[i], id))
      return i;
  }

  assert(0 != 0 && "SM ID could not be found in the RAN Function List");
  return 0;
}

int main(int argc, char* argv[])
{
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <influxdb_token> [period_ms]\n", argv[0]);
    return EXIT_FAILURE;
  }

  strncpy(influxdb_token, argv[1], sizeof(influxdb_token) - 1);

  if (argc >= 3) {
    char *endptr = NULL;
    long val = strtol(argv[2], &endptr, 10);
    if (*endptr != '\0' || val <= 0) {
      fprintf(stderr, "Invalid period_ms value: '%s'. Must be a positive integer.\n", argv[2]);
    } else {
      period_ms = (uint64_t)val;
    }
  }

  if (clear_database_on_startup) {
    influxdb_clear_bucket();
  }

  fr_args_t args = init_fr_args(argc, argv);

  // Init the xApp
  init_xapp_api(&args);
  sleep(1);

  init_kpm_meas_unit_hash_table();

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  defer({ free_e2_node_arr_xapp(&nodes); });

  assert(nodes.len > 0);

  printf("Connected E2 nodes = %d\n", nodes.len);

  pthread_mutexattr_t attr = {0};
  int rc = pthread_mutex_init(&mtx, &attr);
  assert(rc == 0);

  load_slice_from_env();

  sm_ans_xapp_t** hndl = (sm_ans_xapp_t**)calloc(nodes.len, sizeof(sm_ans_xapp_t*));
  assert(hndl != NULL);

  ////////////
  // START KPM
  ////////////
  int const KPM_ran_function = 2;

  for (size_t i = 0; i < nodes.len; ++i) {
    e2_node_connected_xapp_t* n = &nodes.n[i];

    size_t const idx = find_sm_idx(n->rf, n->len_rf, eq_sm, KPM_ran_function);
    assert(n->rf[idx].defn.type == KPM_RAN_FUNC_DEF_E && "KPM is not the received RAN Function");
    // if REPORT Service is supported by E2 node, send SUBSCRIPTION
    // e.g. OAI CU-CP
    const size_t sz_report_styles = n->rf[idx].defn.kpm.sz_ric_report_style_list;
    hndl[i] = calloc(sz_report_styles, sizeof(sm_ans_xapp_t));
    assert(hndl[i] != NULL);
    for (size_t j = 0; j < sz_report_styles; j++) {
      ric_report_style_item_t *report_item = &n->rf[idx].defn.kpm.ric_report_style_list[j];
      // Generate KPM SUBSCRIPTION message
      kpm_sub_data_t kpm_sub = gen_kpm_subs(&n->rf[idx].defn.kpm, report_item);

      hndl[i][j] = report_sm_xapp_api(&n->id, KPM_ran_function, &kpm_sub, sm_cb_kpm);
      assert(hndl[i][j].success == true);

      free_kpm_sub_data(&kpm_sub);
    }
  }
  ////////////
  // END KPM
  ////////////

  xapp_wait_end_api();

  for (int i = 0; i < nodes.len; ++i) {
    e2_node_connected_xapp_t* n = &nodes.n[i];
    size_t const idx = find_sm_idx(n->rf, n->len_rf, eq_sm, KPM_ran_function);
    for (size_t j = 0; j < n->rf[idx].defn.kpm.sz_ric_report_style_list; j++) {
      // Remove the handle previously returned
      if (hndl[i][j].success == true)
        rm_report_sm_xapp_api(hndl[i][j].u.handle);
    }
    free(hndl[i]);
  }
  free(hndl);

  free_kpm_meas_unit_hash_table();

  // Stop the xApp
  while (try_stop_xapp_api() == false)
    usleep(1000);

  printf("Test xApp run SUCCESSFULLY\n");
}
