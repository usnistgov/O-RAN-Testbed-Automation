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

#include "../../../../src/util/alg_ds/alg/defer.h"
#include "../../../../src/util/alg_ds/alg/murmur_hash_32.h"
#include "../../../../src/util/alg_ds/ds/assoc_container/assoc_generic.h"
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"
#include "../../../../src/util/e.h"
#include "../../../../src/util/time_now_us.h"
#include "../../../../src/xApp/e42_xapp_api.h"
#include "../metrics_factory.h"
#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

// Set to the interval in milliseconds at which the xApp should write to the CSV file
static uint64_t period_ms = 1000;

// Set to true if samples containing RSRP.Count == 0 are to be filtered,
// which is expected to give more stable results at the expense of some data loss
const bool filter_invalid_rsrp_samples = false;

static pthread_mutex_t mtx;

static assoc_ht_open_t ht = {0};

static uint32_t hash_func(const void *key_v) {
  char *key = *(char **)(key_v);
  static const uint32_t seed = 42;
  return murmur3_32((uint8_t *)key, strlen(key), seed);
}

static bool cmp_str(const void *a, const void *b) {
  char *a_str = *(char **)(a);
  char *b_str = *(char **)(b);

  int const ret = strcmp(a_str, b_str);
  return ret == 0;
}

static void free_str(void *key, void *value) {
  free(*(char **)key);
  free(value);
}

static void free_kpm_meas_unit_hash_table(void) {
  assoc_ht_open_free(&ht);
}

static void init_kpm_meas_unit_hash_table(void) {
  FILE *fp = fopen(KPM_MEAS_LIST, "r");
  if (!fp) {
    printf("Cannot open the file \"%s\".\n", KPM_MEAS_LIST);
    perror("Error");
    return;
  }

  assoc_ht_open_init(&ht, sizeof(char *), cmp_str, free_str, hash_func);
  char line[128];
  while (fgets(line, sizeof(line), fp)) {
    char *col1, *col2;
    sscanf(line, "%ms %ms", &col1, &col2);
    assoc_ht_open_insert(&ht, &col1, sizeof(char *), col2);
  }
  fclose(fp);
}

static char *get_meas_unit(const char *name) {
  char *val = assoc_ht_open_value(&ht, &name);
  if (!val || strcmp(val, "[]") == 0) {
    return "";
  }
  return val;
}

// Overwritten if environment variables SST and SD are set
static uint8_t cfg_slicing_sst = 1;
static uint32_t cfg_slicing_sd = 0xFFFFFF; // 0xFFFFFF for any SD

// Variables that change during runtime
bool csv_wrote_header = false;
const char *csv_file_path = NULL;
char csv_header_buffer[2048];
char csv_line_buffer[9000];

bool csv_wrote_cell_header = false;
char csv_cell_file_path[1024];
char csv_cell_header_buffer[2048];
char csv_cell_line_buffer[9000];
bool is_cell_metric = false;

typedef struct {
  char *name;
  char *text;
} csv_column_t;

typedef struct {
  csv_column_t *columns;
  size_t count;
  size_t capacity;
} csv_schema_t;

static csv_schema_t csv_ue_schema = {0};
static csv_schema_t csv_cell_schema = {0};

unsigned int csv_num_rows = 0;
uint64_t current_ue_id = 0;
bool filter_current_sample = false;
int64_t prev_now = 0;

static char current_e2_node_id[256];

static bool csv_append_name_to_csv_header(const char *name, const char *unit) {
  char *target_buffer = is_cell_metric ? csv_cell_header_buffer : csv_header_buffer;
  size_t buffer_size = is_cell_metric ? sizeof(csv_cell_header_buffer) : sizeof(csv_header_buffer);

  if (!name) {
    name = "";
  }
  if (!unit) {
    unit = "";
  }
  size_t current_len = strlen(target_buffer);
  size_t name_len = strlen(name);
  size_t unit_len = strlen(unit);

  // Don't overflow the buffer
  if (current_len + name_len + unit_len + 4 < buffer_size) { // +4 for " ()", comma, and null terminator
    if (unit_len > 0) {
      snprintf(target_buffer + current_len, buffer_size - current_len, "%s (%s),", name, unit);
    } else {
      snprintf(target_buffer + current_len, buffer_size - current_len, "%s,", name);
    }
    return true;
  }

  fprintf(stderr, "CSV header buffer is full, cannot append more names.\n");
  return false;
}

static csv_schema_t *csv_get_schema(bool cell_metric) {
  return cell_metric ? &csv_cell_schema : &csv_ue_schema;
}

static void csv_clear_metric_values(void) {
  csv_schema_t *schema = csv_get_schema(is_cell_metric);
  for (size_t i = 0; i < schema->count; i++) {
    free(schema->columns[i].text);
    schema->columns[i].text = NULL;
  }
}

static void csv_free_schema(csv_schema_t *schema) {
  for (size_t i = 0; i < schema->count; i++) {
    free(schema->columns[i].name);
    free(schema->columns[i].text);
  }
  free(schema->columns);
  *schema = (csv_schema_t){0};
}

static void clean_unit(char *dst, size_t dst_len, const char *unit) {
  size_t len = unit == NULL ? 0 : strlen(unit);
  if (len > 2 && unit[0] == '[' && unit[len - 1] == ']') {
    snprintf(dst, dst_len, "%.*s", (int)(len - 2), unit + 1);
  } else {
    snprintf(dst, dst_len, "%s", unit == NULL ? "" : unit);
  }
}

static bool csv_add_metric_column(bool cell_metric, const char *name, const char *unit) {
  csv_schema_t *schema = csv_get_schema(cell_metric);
  for (size_t i = 0; i < schema->count; i++) {
    if (strcmp(schema->columns[i].name, name) == 0) {
      return true;
    }
  }

  if ((cell_metric && csv_wrote_cell_header) || (!cell_metric && csv_wrote_header)) {
    fprintf(stderr, "Cannot add metric %s after the %s CSV header was written.\n", name, cell_metric ? "cell" : "UE");
    return false;
  }

  if (schema->count == schema->capacity) {
    size_t new_capacity = schema->capacity == 0 ? 16 : schema->capacity * 2;
    csv_column_t *columns = realloc(schema->columns, new_capacity * sizeof(*columns));
    if (columns == NULL) {
      return false;
    }
    schema->columns = columns;
    schema->capacity = new_capacity;
  }

  char normalized_unit[64];
  clean_unit(normalized_unit, sizeof(normalized_unit), unit);
  csv_column_t *column = &schema->columns[schema->count];
  *column = (csv_column_t){.name = strdup(name)};
  if (column->name == NULL) {
    *column = (csv_column_t){0};
    return false;
  }

  is_cell_metric = cell_metric;
  if (!csv_append_name_to_csv_header(name, normalized_unit)) {
    free(column->name);
    *column = (csv_column_t){0};
    return false;
  }
  schema->count++;
  return true;
}

static void csv_set_metric_value(const char *name, const char *text) {
  csv_schema_t *schema = csv_get_schema(is_cell_metric);

  for (size_t i = 0; i < schema->count; i++) {
    csv_column_t *column = &schema->columns[i];
    if (strcmp(column->name, name) != 0) {
      continue;
    }

    char *copy = strdup(text ? text : "");
    if (copy == NULL) {
      fprintf(stderr, "Failed to allocate CSV value for %s.\n", name);
      filter_current_sample = true;
      return;
    }
    free(column->text);
    column->text = copy;
    return;
  }

  fprintf(stderr, "Received metric %s that was not present in the negotiated %s subscription schema.\n", name,
          is_cell_metric ? "cell" : "UE");
  filter_current_sample = true;
}

static void csv_append_string_to_csv_line(const char *str) {
  if (!str) {
    str = "";
  }
  char *target_buffer = is_cell_metric ? csv_cell_line_buffer : csv_line_buffer;
  size_t buffer_size = is_cell_metric ? sizeof(csv_cell_line_buffer) : sizeof(csv_line_buffer);
  size_t current_len = strlen(target_buffer);

  if (current_len + strlen(str) + 32 < buffer_size) {
    if (strpbrk(str, ",\"\r\n") != NULL) {
      snprintf(target_buffer + current_len, buffer_size - current_len, "\"%s\",", str);
    } else {
      snprintf(target_buffer + current_len, buffer_size - current_len, "%s,", str);
    }
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot append more values.\n");
  }
}

static void csv_prepend_e2_node_id(void) {
  char e2_node_id_buffer[600];
  snprintf(e2_node_id_buffer, sizeof(e2_node_id_buffer), "%s,", current_e2_node_id);

  size_t e2_node_id_len = strlen(e2_node_id_buffer);
  char *target_buffer = is_cell_metric ? csv_cell_line_buffer : csv_line_buffer;
  size_t buffer_size = is_cell_metric ? sizeof(csv_cell_line_buffer) : sizeof(csv_line_buffer);
  size_t current_len = strlen(target_buffer);

  if (e2_node_id_len + current_len < buffer_size) {
    // Temporary buffer to construct the new line
    char temp_buffer[9000];
    size_t total_len = 0;
    temp_buffer[0] = '\0';
    strncat(temp_buffer, e2_node_id_buffer, sizeof(temp_buffer) - 1);
    total_len = strlen(temp_buffer);
    if (total_len < sizeof(temp_buffer) - 1) {
      strncat(temp_buffer, target_buffer, sizeof(temp_buffer) - 1 - total_len);
    }
    strncpy(target_buffer, temp_buffer, buffer_size - 1);
    target_buffer[buffer_size - 1] = '\0';
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot prepend E2 Node ID.\n");
  }
}
static void csv_prepend_ue_id() {
  // Ensure the current UE ID is valid
  if (current_ue_id == 0) {
    if (filter_invalid_rsrp_samples) {
      fprintf(stderr, "ERROR: No valid UE ID found.\n");
    }
  }

  // Ensure the buffer won't overflow
  char ue_id_buffer[32];
  snprintf(ue_id_buffer, sizeof(ue_id_buffer), "%" PRIu64 ",", current_ue_id);
  size_t ue_id_len = strlen(ue_id_buffer);
  size_t current_len = strlen(csv_line_buffer);

  if (ue_id_len + current_len < sizeof(csv_line_buffer)) {
    // Use a temporary buffer to construct the new line
    char temp_buffer[sizeof(csv_line_buffer)];
    size_t total_len = 0;
    temp_buffer[0] = '\0';
    strncat(temp_buffer, ue_id_buffer, sizeof(temp_buffer) - 1);
    total_len = strlen(temp_buffer);
    if (total_len < sizeof(temp_buffer) - 1) {
      strncat(temp_buffer, csv_line_buffer, sizeof(temp_buffer) - 1 - total_len);
    }
    strncpy(csv_line_buffer, temp_buffer, sizeof(csv_line_buffer) - 1);
    csv_line_buffer[sizeof(csv_line_buffer) - 1] = '\0';
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot prepend UE ID.\n");
  }
}

static void csv_prepend_timestamp(int64_t arrival_ms, int64_t latency, int64_t batch_id) {

  // Ensure the timestamp is non-negative
  if (arrival_ms < 0) {
    fprintf(stderr, "ERROR: Negative timestamp value encountered.\n");
    return;
  }

  int64_t reporting_timestamp_offset = 0;
  if (prev_now > 0) {
    reporting_timestamp_offset = arrival_ms - prev_now - period_ms;
  }

  char prefix_buffer[128];
  if (prev_now <= 0) {
    snprintf(prefix_buffer, sizeof(prefix_buffer), "%" PRId64 ",%" PRId64 ",,%" PRId64 ",", arrival_ms, batch_id,
             latency);
  } else {
    snprintf(prefix_buffer, sizeof(prefix_buffer), "%" PRId64 ",%" PRId64 ",%" PRId64 ",%" PRId64 ",", arrival_ms,
             batch_id, reporting_timestamp_offset, latency);
  }

  // Ensure the buffer won't overflow
  size_t prefix_len = strlen(prefix_buffer);
  char *target_buffer = is_cell_metric ? csv_cell_line_buffer : csv_line_buffer;
  size_t buffer_size = is_cell_metric ? sizeof(csv_cell_line_buffer) : sizeof(csv_line_buffer);
  size_t current_len = strlen(target_buffer);

  if (prefix_len + current_len < buffer_size) {
    // Temporary buffer to construct the new line
    char temp_buffer[9000];
    temp_buffer[0] = '\0';
    strncat(temp_buffer, prefix_buffer, sizeof(temp_buffer) - 1);
    strncat(temp_buffer, target_buffer, sizeof(temp_buffer) - strlen(temp_buffer) - 1);
    strncpy(target_buffer, temp_buffer, buffer_size - 1);
    target_buffer[buffer_size - 1] = '\0';
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot prepend timestamp and offset.\n");
  }
}

static void write_csv_header_to_file() {
  if (is_cell_metric) {
    if (!csv_wrote_cell_header && csv_cell_file_path[0] != '\0') {
      FILE *file = fopen(csv_cell_file_path, "w");
      if (file == NULL) {
        fprintf(stderr, "Failed to open CSV file: %s\n", csv_cell_file_path);
        return;
      }
      fprintf(file, "%s\n", csv_cell_header_buffer);
      fclose(file);

      csv_wrote_cell_header = true;
      printf("CSV cell header written to file: %s\n", csv_cell_file_path);
    }
  } else {
    if (!csv_wrote_header && csv_file_path != NULL) {
      FILE *file = fopen(csv_file_path, "w");
      if (file == NULL) {
        fprintf(stderr, "Failed to open CSV file: %s\n", csv_file_path);
        return;
      }
      fprintf(file, "%s\n", csv_header_buffer);
      fclose(file);

      csv_wrote_header = true;
      printf("CSV header written to file: %s\n", csv_file_path);
    }
  }
}

static void write_csv_line_to_file() {
  if (is_cell_metric) {
    if (csv_wrote_cell_header && csv_cell_file_path[0] != '\0') {
      FILE *file = fopen(csv_cell_file_path, "a");
      if (file == NULL) {
        fprintf(stderr, "Failed to open CSV cell file for appending: %s\n", csv_cell_file_path);
        return;
      }
      fprintf(file, "%s\n", csv_cell_line_buffer);
      fclose(file);

      printf("CSV cell line written to file: %s\n", csv_cell_file_path);
    }
    // Reset the line buffer for the next entry
    memset(csv_cell_line_buffer, 0, sizeof(csv_cell_line_buffer));
  } else {
    if (csv_wrote_header && csv_file_path != NULL) {
      FILE *file = fopen(csv_file_path, "a");
      if (file == NULL) {
        fprintf(stderr, "Failed to open CSV file for appending: %s\n", csv_file_path);
        return;
      }
      fprintf(file, "%s\n", csv_line_buffer);
      fclose(file);

      printf("CSV line written to file: %s\n", csv_file_path);
    }
    // Reset the line buffer for the next entry
    memset(csv_line_buffer, 0, sizeof(csv_line_buffer));
  }
}

static void log_gnb_ue_id(ue_id_e2sm_t ue_id) {
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
}

static void log_du_ue_id(ue_id_e2sm_t ue_id) {
  printf("UE ID type = gNB-DU, gnb_cu_ue_f1ap = %u\n", ue_id.gnb_du.gnb_cu_ue_f1ap);
  if (ue_id.gnb_du.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb_du.ran_ue_id); // RAN UE NGAP ID
  }
  current_ue_id = ue_id.gnb_du.gnb_cu_ue_f1ap; // Update the global UE ID
}

static void log_cuup_ue_id(ue_id_e2sm_t ue_id) {
  printf("UE ID type = gNB-CU-UP, gnb_cu_cp_ue_e1ap = %u\n", ue_id.gnb_cu_up.gnb_cu_cp_ue_e1ap);
  if (ue_id.gnb_cu_up.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb_cu_up.ran_ue_id); // RAN UE NGAP ID
  }
  current_ue_id = ue_id.gnb_cu_up.gnb_cu_cp_ue_e1ap; // Update the global UE ID
}

typedef void (*log_ue_id)(ue_id_e2sm_t ue_id);

static log_ue_id log_ue_id_e2sm[END_UE_ID_E2SM] = {
    log_gnb_ue_id, // common for gNB-mono, CU and CU-CP
    log_du_ue_id,  log_cuup_ue_id, NULL, NULL, NULL, NULL,
};

static void log_int_value(const char *name_str, const label_info_lst_t label_info,
                          const meas_record_lst_t meas_record) {
  (void)label_info;
  char value[32];
  snprintf(value, sizeof(value), "%ld", (long)meas_record.int_val);
  csv_set_metric_value(name_str, value);

  // if (label_info.noLabel != NULL) {
  //   printf("%s = %d%s%s\n", name_str, meas_record.int_val, *name_unit ? " " : "", name_unit);
  // } else if (label_info.distBinX != NULL && meas_record.int_val > 0) {
  //   printf("%s[BinX=%d][BinY=%d][BinZ=%d] = %d%s%s\n", name_str, *label_info.distBinX, *label_info.distBinY,
  //   *label_info.distBinZ, meas_record.int_val, *name_unit ? " " : "", name_unit);
  // }

  // If the measurement is RSRP.Count and the value is 0, the data is invalid
  if (filter_invalid_rsrp_samples && strcmp("RSRP.Count", name_str) == 0) {
    if (meas_record.int_val == 0) {
      filter_current_sample = true;
      printf("\n\tNumber of RSRP measurements was zero, skipping sample to avoid divide by zero.\n\n");
    }
  }
}

static void log_real_value(const char *name_str, const label_info_lst_t label_info,
                           const meas_record_lst_t meas_record) {
  (void)label_info;
  char value[32] = "";
  if (!isnan(meas_record.real_val)) {
    snprintf(value, sizeof(value), "%.2f", meas_record.real_val);
  }
  csv_set_metric_value(name_str, value);

  // printf("%s = %.2f%s%s\n", name_str, meas_record.real_val, *name_unit ? " " : "", name_unit);
}

static void log_no_value(const char *name_str, const label_info_lst_t label_info, const meas_record_lst_t meas_record) {
  (void)label_info;
  (void)meas_record;
  csv_set_metric_value(name_str, "");
}

typedef void (*log_meas_value)(const char *name_str, const label_info_lst_t label_info,
                               const meas_record_lst_t meas_record);

static log_meas_value get_meas_value[END_MEAS_VALUE] = {
    log_int_value,
    log_real_value,
    log_no_value,
};

static void match_meas_name_type(const meas_type_t meas_type, const label_info_lst_t label_info,
                                 const meas_record_lst_t record_item) {
  // Get the value of the Measurement
  if (record_item.value >= END_MEAS_VALUE || get_meas_value[record_item.value] == NULL) {
    printf("[xApp] WARNING: Unsupported measurement value type %d\n", record_item.value);
    return;
  }
  char *name_str = cp_ba_to_str(meas_type.name);
  get_meas_value[record_item.value](name_str, label_info, record_item);
  free(name_str);
}

static void match_id_meas_type(const meas_type_t meas_type, const label_info_lst_t label_info,
                               const meas_record_lst_t record_item) {
  (void)meas_type;
  (void)label_info;
  (void)record_item;
  assert(false && "ID Measurement Type not yet supported");
}

typedef void (*check_meas_type)(const meas_type_t meas_type, const label_info_lst_t label_info,
                                const meas_record_lst_t meas_record);

static check_meas_type match_meas_type[END_MEAS_TYPE] = {
    match_meas_name_type,
    match_id_meas_type,
};

static void finish_measurement_row(int64_t collect_start_time, int64_t latency, int64_t batch_id) {
  const int64_t arrival_ms = collect_start_time / 1000 + latency;
  if (filter_current_sample) {
    // Log an empty measurement row after the 0
    printf("Logging empty measurement row\n");
    csv_clear_metric_values();
  }

  csv_schema_t *schema = csv_get_schema(is_cell_metric);
  for (size_t i = 0; i < schema->count; i++) {
    csv_append_string_to_csv_line(schema->columns[i].text);
  }

  if (!is_cell_metric) {
    csv_prepend_ue_id();
  }
  csv_prepend_e2_node_id();
  csv_prepend_timestamp(arrival_ms, latency, batch_id);
  write_csv_line_to_file();
  csv_clear_metric_values();
  filter_current_sample = false;
  ++csv_num_rows;
  printf("Samples collected = %u\n", csv_num_rows);
}

static void log_kpm_measurements(kpm_ind_msg_format_1_t const *msg_frm_1, int64_t collect_start_time, int64_t latency,
                                 int64_t batch_id, bool is_cell_metric_local) {
  is_cell_metric = is_cell_metric_local;

  assert(msg_frm_1->meas_info_lst_len > 0 && "Cannot correctly print measurements");

  // UE Measurements per granularity period
  for (size_t j = 0; j < msg_frm_1->meas_data_lst_len; j++) {
    meas_data_lst_t const data_item = msg_frm_1->meas_data_lst[j];

    size_t rec_idx = 0;
    for (size_t i = 0; i < msg_frm_1->meas_info_lst_len; i++) {
      const meas_info_format_1_lst_t info_item = msg_frm_1->meas_info_lst[i];

      if (info_item.label_info_lst_len > 1 && info_item.meas_type.type == NAME_MEAS_TYPE &&
          info_item.label_info_lst[0].distBinX != NULL) {
        char *name_str = cp_ba_to_str(info_item.meas_type.name);
        factory_metrics_array_t generated_metrics =
            process_metric_factory(current_e2_node_id, name_str, info_item.label_info_lst, info_item.label_info_lst_len,
                                   data_item.meas_record_lst, rec_idx);

        for (size_t k = 0; k < generated_metrics.count; k++) {
          factory_metric_t m = generated_metrics.metrics[k];

          char metric_value[32] = "";
          if (m.value_type == 0) {
            snprintf(metric_value, sizeof(metric_value), "%d", m.int_val);
          } else if (!isnan(m.real_val)) {
            snprintf(metric_value, sizeof(metric_value), "%.2f", m.real_val);
          }
          csv_set_metric_value(m.name, metric_value);
        }
        free_factory_metrics(&generated_metrics);

        // Build the JSON array string
        char arr_str[8192];
        format_meas_record_array(arr_str, sizeof(arr_str), info_item.label_info_lst, info_item.label_info_lst_len,
                                 data_item.meas_record_lst, rec_idx);
        rec_idx += info_item.label_info_lst_len;

        csv_set_metric_value(name_str, arr_str);

        free(name_str);
      } else {
        for (size_t z = 0; z < info_item.label_info_lst_len; z++) {
          const label_info_lst_t label_info = info_item.label_info_lst[z];
          const meas_record_lst_t record_item = data_item.meas_record_lst[rec_idx++];

          match_meas_type[info_item.meas_type.type](info_item.meas_type, label_info, record_item);

          if (data_item.incomplete_flag && *data_item.incomplete_flag == TRUE_ENUM_VALUE) {
            printf("Measurement Record not reliable");
          }
        }
      }
    }
  }

  finish_measurement_row(collect_start_time, latency, batch_id);
}

static void log_kpm_ind_msg_frm_3(kpm_ind_msg_format_3_t const *msg, int64_t collect_start_time, int64_t latency,
                                  int64_t batch_id) {
  // Reported list of measurements per UE
  for (size_t i = 0; i < msg->ue_meas_report_lst_len; i++) {
    // log UE ID
    ue_id_e2sm_t const ue_id_e2sm = msg->meas_report_per_ue[i].ue_meas_report_lst;
    ue_id_e2sm_e const type = ue_id_e2sm.type;
    if (type < END_UE_ID_E2SM && log_ue_id_e2sm[type] != NULL) {
      log_ue_id_e2sm[type](ue_id_e2sm);
    }

    // log measurements
    log_kpm_measurements(&msg->meas_report_per_ue[i].ind_msg_format_1, collect_start_time, latency, batch_id, false);
  }
}

typedef struct {
  int64_t collect_start_time;
  int64_t latency;
  int64_t batch_id;
} csv_format_2_context_t;

static void begin_csv_format_2_ue(void *context, const ue_id_e2sm_t *ue_id) {
  (void)context;
  is_cell_metric = false;
  if (ue_id->type < END_UE_ID_E2SM && log_ue_id_e2sm[ue_id->type] != NULL) {
    log_ue_id_e2sm[ue_id->type](*ue_id);
  }
}

static void add_csv_format_2_measurement(void *context, const meas_type_t *meas_type, const label_info_lst_t *label,
                                         const meas_record_lst_t *record) {
  (void)context;
  match_meas_type[meas_type->type](*meas_type, *label, *record);
}

static void finish_csv_format_2_ue(void *context, bool incomplete) {
  csv_format_2_context_t *csv = context;
  if (incomplete) {
    printf("Measurement Record not reliable\n");
  }
  finish_measurement_row(csv->collect_start_time, csv->latency, csv->batch_id);
}

static void log_kpm_ind_msg_frm_2(const kpm_ind_msg_format_2_t *msg, int64_t collect_start_time, int64_t latency,
                                  int64_t batch_id) {
  csv_format_2_context_t context = {
      .collect_start_time = collect_start_time,
      .latency = latency,
      .batch_id = batch_id,
  };
  const kpm_format_2_visitor_t visitor = {
      .begin_ue = begin_csv_format_2_ue,
      .measurement = add_csv_format_2_measurement,
      .end_ue = finish_csv_format_2_ue,
  };
  kpm_visit_format_2(msg, &visitor, &context);
}

static void load_slice_from_env(void) {
  const char *s;
  char *end = NULL;
  errno = 0;

  s = getenv("SST");
  if (s && *s) {
    unsigned long v = strtoul(s, &end, 0);
    if (end != s && errno == 0 && v <= 0xFFul) {
      cfg_slicing_sst = (uint8_t)v;
    }
  }

  errno = 0;
  end = NULL;
  s = getenv("SD");
  if (s && *s) {
    unsigned long v = strtoul(s, &end, 0);
    if (end != s && errno == 0) {
      cfg_slicing_sd = ((uint32_t)v) & 0xFFFFFFu;
    }
  }

  printf("[xApp] Using S-NSSAI SST=%u SD=%06x (env SST/SD can override)\n", (unsigned)cfg_slicing_sst,
         (unsigned)(cfg_slicing_sd & 0xFFFFFFu));
}

static void sm_cb_kpm(sm_ag_if_rd_t const *rd, global_e2_node_id_t const *node_id) {
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0);

  // Reading Indication Message Format 3
  kpm_ind_data_t const *ind = &rd->ind.kpm.ind;
  kpm_ric_ind_hdr_format_1_t const *hdr_frm_1 = &ind->hdr.kpm_ric_ind_hdr_format_1;
  if (node_id != NULL) {
    kpm_remember_ues(node_id, &ind->msg);
  }

  lock_guard(&mtx);
  format_e2_node_id(current_e2_node_id, sizeof(current_e2_node_id), node_id);
  int64_t const now = time_now_us();
  int64_t latency = (now - hdr_frm_1->collectStartTime) / 1000;

  int64_t collect_start_time_ms = hdr_frm_1->collectStartTime / 1000;
  static int64_t last_collect_start_time = 0;
  static int64_t current_batch_id = 0;
  static int64_t current_batch_arrival_ms = 0;

  if (current_batch_id == 0) {
    current_batch_id = 1;
    last_collect_start_time = collect_start_time_ms;
    current_batch_arrival_ms = collect_start_time_ms + latency;
  } else {
    // Find the nearest batch ID based on collect start time and period
    if (labs(collect_start_time_ms - last_collect_start_time) > period_ms / 2) {
      current_batch_id++;
      last_collect_start_time = collect_start_time_ms;
      prev_now = current_batch_arrival_ms;
      current_batch_arrival_ms = collect_start_time_ms + latency;
    }
  }

  static int counter = 1;
  {
    printf("\n%7d KPM ind_msg latency = %" PRId64 " [ms]\n", counter, latency); // xApp <-> E2 Node

    if (ind->msg.type == FORMAT_1_INDICATION_MESSAGE) {
      format_kpm_cell_node_id(current_e2_node_id, sizeof(current_e2_node_id), node_id);
      log_kpm_measurements(&ind->msg.frm_1, hdr_frm_1->collectStartTime, latency, current_batch_id, true);
    } else if (ind->msg.type == FORMAT_2_INDICATION_MESSAGE) {
      log_kpm_ind_msg_frm_2(&ind->msg.frm_2, hdr_frm_1->collectStartTime, latency, current_batch_id);
    } else if (ind->msg.type == FORMAT_3_INDICATION_MESSAGE) {
      log_kpm_ind_msg_frm_3(&ind->msg.frm_3, hdr_frm_1->collectStartTime, latency, current_batch_id);
    } else {
      printf("KPM Indication Message %d logging not yet implemented.\n", ind->msg.type);
    }
    counter++;
  }
}

static bool csv_add_report_style_columns(ric_report_style_item_t const *report_item) {
  assert(report_item->report_style_type < END_RIC_SERVICE_REPORT);
  const bool cell_metric = report_item->report_style_type == STYLE_1_RIC_SERVICE_REPORT;

  for (size_t i = 0; i < report_item->meas_info_for_action_lst_len; i++) {
    char *name = cp_ba_to_str(report_item->meas_info_for_action_lst[i].name);
    factory_metrics_array_t derived = describe_metric_factory(name);
    for (size_t j = 0; j < derived.count; j++) {
      if (!csv_add_metric_column(cell_metric, derived.metrics[j].name, derived.metrics[j].unit)) {
        free_factory_metrics(&derived);
        free(name);
        return false;
      }
    }
    free_factory_metrics(&derived);

    if (!csv_add_metric_column(cell_metric, name, get_meas_unit(name))) {
      free(name);
      return false;
    }
    free(name);
  }
  return true;
}

int main(int argc, char *argv[]) {
  if (argc < 3) {
    fprintf(stderr, "Usage: %s <csv_file_path> <period_ms> [other arguments]\n", argv[0]);
    return EXIT_FAILURE;
  }

  csv_file_path = argv[1];
  printf("CSV file path provided: %s\n", csv_file_path);

  // Verify the CSV file path ends with ".csv"
  size_t path_len = strlen(csv_file_path);
  if (path_len < 4 || strcmp(csv_file_path + path_len - 4, ".csv") != 0) {
    fprintf(stderr, "ERROR: The file path must end with '.csv'.\n");
    return EXIT_FAILURE;
  }

  if (path_len + 6 < sizeof(csv_cell_file_path)) {
    snprintf(csv_cell_file_path, sizeof(csv_cell_file_path), "%.*s", (int)(path_len - 4), csv_file_path);
    csv_cell_file_path[path_len - 4] = '\0';
    strcat(csv_cell_file_path, "_Cells.csv");
    printf("CSV cell file path constructed: %s\n", csv_cell_file_path);
  } else {
    csv_cell_file_path[0] = '\0';
    fprintf(stderr, "WARNING: The file path is too long to construct cell file path.\n");
  }

  char *endptr = NULL;
  long val = strtol(argv[2], &endptr, 10);
  if (*endptr != '\0' || val <= 0) {
    fprintf(stderr, "Invalid period_ms value: '%s'. Must be a positive integer.\n", argv[2]);
    return EXIT_FAILURE;
  }
  period_ms = (uint64_t)val;

  is_cell_metric = false;
  csv_wrote_header = false;
  csv_append_name_to_csv_header("Time", "UNIX ms");
  csv_append_name_to_csv_header("Batch ID (Mapping Cell with UE)", "");
  csv_append_name_to_csv_header("Reporting Time Offset", "ms");
  csv_append_name_to_csv_header("Indication Latency", "ms");
  csv_append_name_to_csv_header("E2 Node ID", "");
  csv_append_name_to_csv_header("UE ID", "");

  is_cell_metric = true;
  csv_wrote_cell_header = false;
  csv_append_name_to_csv_header("Time", "UNIX ms");
  csv_append_name_to_csv_header("Batch ID (Mapping Cell with UE)", "");
  csv_append_name_to_csv_header("Reporting Time Offset", "ms");
  csv_append_name_to_csv_header("Indication Latency", "ms");
  csv_append_name_to_csv_header("E2 Node ID", "");

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

  ////////////
  // START KPM
  ////////////
  const uint32_t KPM_ran_function = 2;

  // Build each shared schema from the union of metrics advertised by every subscribed E2 node.
  for (size_t i = 0; i < nodes.len; ++i) {
    e2_node_connected_xapp_t *n = &nodes.n[i];
    sm_ran_function_t *ran_function = kpm_find_ran_function(n, KPM_ran_function);

    const size_t sz_report_styles = ran_function->defn.kpm.sz_ric_report_style_list;
    for (size_t j = 0; j < sz_report_styles; j++) {
      ric_report_style_item_t *report_item = &ran_function->defn.kpm.ric_report_style_list[j];
      if (!csv_add_report_style_columns(report_item)) {
        fprintf(stderr, "Failed to construct the dynamic CSV schema.\n");
        return EXIT_FAILURE;
      }
    }
  }

  is_cell_metric = false;
  write_csv_header_to_file();
  is_cell_metric = true;
  write_csv_header_to_file();

  const kpm_subscription_config_t subscription_config = {
      .period_ms = period_ms,
      .sst = cfg_slicing_sst,
      .sd = cfg_slicing_sd,
      .ue_wait_ms = 5000,
  };
  kpm_subscription_set_t subscriptions =
      kpm_subscribe_report_styles(&nodes, KPM_ran_function, subscription_config, sm_cb_kpm);
  ////////////
  // END KPM
  ////////////

  xapp_wait_end_api();
  kpm_unsubscribe_report_styles(&subscriptions);

  // Stop the xApp
  while (try_stop_xapp_api() == false) {
    usleep(1000);
  }

  free_kpm_meas_unit_hash_table();
  kpm_reset_ue_registry();
  csv_free_schema(&csv_ue_schema);
  csv_free_schema(&csv_cell_schema);

  printf("Test xApp run SUCCESSFULLY\n");
}
