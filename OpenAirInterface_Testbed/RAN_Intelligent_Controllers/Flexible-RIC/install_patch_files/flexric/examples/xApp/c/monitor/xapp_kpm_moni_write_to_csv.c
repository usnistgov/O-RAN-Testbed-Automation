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
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"
#include "../../../../src/util/e.h"
#include "../../../../src/sm/kpm_sm/kpm_data_ie_wrapper.h"

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <inttypes.h>
#include <math.h>

// Set to the interval in milliseconds at which the xApp should write to the CSV file
static uint64_t period_ms = 1000;

// Lowering the timestamp precision groups measurements from multiple UEs under the same timestamp, making it easier to identify simultaneous connections.
uint64_t timestamp_precision = 10;

// For metrics based on the difference between indication messages, the first sample may give a wrong value, so it is skipped.
bool skip_first_sample = true;

// Set to true if samples containing RSRP.Count == 0 are to be filtered,
// which is expected to give more stable results at the expense of some data loss
const bool filter_invalid_rsrp_samples = false;

// Variables that change during runtime
static pthread_mutex_t mtx;
bool csv_wrote_header = false;
const char *csv_file_path = NULL;
char csv_header_buffer[2048];
char csv_line_buffer[2048];
unsigned int csv_num_rows = 0;
uint64_t current_ue_id = 0;
bool filter_current_sample = false;
int64_t prev_now = 0;

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
    log_du_ue_id,
    log_cuup_ue_id,
    NULL,
    NULL,
    NULL,
    NULL,
};

static void csv_append_name_to_csv_header(byte_array_t name, byte_array_t unit) {
  size_t current_len = strlen(csv_header_buffer);
  size_t name_len = name.len;
  size_t unit_len = unit.len;

  // Don't overflow the buffer
  if (current_len + name_len + unit_len + 4 < sizeof(csv_header_buffer)) { // +4 for " ()", comma, and null terminator
    if (unit.buf != NULL && unit_len > 0) {
      snprintf(csv_header_buffer + current_len, sizeof(csv_header_buffer) - current_len, "%.*s (%.*s),", (int)name_len, name.buf, (int)unit_len, unit.buf);
    } else {
      snprintf(csv_header_buffer + current_len, sizeof(csv_header_buffer) - current_len, "%.*s,", (int)name_len, name.buf);
    }
  } else {
    fprintf(stderr, "CSV header buffer is full, cannot append more names.\n");
  }
}

static void csv_append_int_to_csv_line(meas_record_lst_t meas_record) {
  size_t current_len = strlen(csv_line_buffer);

  if (current_len + 32 < sizeof(csv_line_buffer)) { // Reserve space for int/float and comma
    snprintf(csv_line_buffer + current_len, sizeof(csv_line_buffer) - current_len, "%d,", meas_record.int_val);
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot append more values.\n");
  }
}

static void csv_append_real_to_csv_line(meas_record_lst_t meas_record) {
  size_t current_len = strlen(csv_line_buffer);

  if (current_len + 32 < sizeof(csv_line_buffer)) { // Reserve space for float and comma
    if (isnan(meas_record.real_val)) {
      snprintf(csv_line_buffer + current_len, sizeof(csv_line_buffer) - current_len, ",");
    } else {
      snprintf(csv_line_buffer + current_len, sizeof(csv_line_buffer) - current_len, "%.2f,", meas_record.real_val);
    }
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot append more values.\n");
  }
}

static void csv_prepend_ue_id() {
  // Ensure the current UE ID is valid
  if (current_ue_id == 0) {
    fprintf(stderr, "Error: No valid UE ID found.\n");
    return;
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
    fprintf(stderr, "CSV line buffer is full (current size: %zu, required size: %zu), cannot prepend UE ID.\n", current_len, ue_id_len + current_len);
  }
}


static void csv_prepend_timestamp() {
  int64_t now = time_now_us();
  // Convert to milliseconds
  now /= 1000;

  // Ensure the timestamp is non-negative
  if (now < 0) {
    fprintf(stderr, "Error: Negative timestamp value encountered.\n");
    return;
  }

  int64_t now_adjusted_precision = now - (now % timestamp_precision);
  char timestamp_buffer[32];
  snprintf(timestamp_buffer, sizeof(timestamp_buffer), "%" PRId64 ",", now_adjusted_precision);

  int64_t reporting_timestamp_offset;
  char offset_buffer[32];
  if (prev_now <= 0) {
    reporting_timestamp_offset = 0;
    snprintf(offset_buffer, sizeof(offset_buffer), ",");
  } else {
    reporting_timestamp_offset = (now - prev_now) - period_ms;
    snprintf(offset_buffer, sizeof(offset_buffer), "%" PRId64 ",", reporting_timestamp_offset);
  }

  // Ensure the buffer won't overflow
  size_t timestamp_len = strlen(timestamp_buffer);
  size_t offset_len = strlen(offset_buffer);
  size_t current_len = strlen(csv_line_buffer);

  if (timestamp_len + offset_len + current_len < sizeof(csv_line_buffer)) {
    // Use a temporary buffer to construct the new line
    char temp_buffer[sizeof(csv_line_buffer)];
    temp_buffer[0] = '\0';
    strncat(temp_buffer, timestamp_buffer, sizeof(temp_buffer) - 1);
    strncat(temp_buffer, offset_buffer, sizeof(temp_buffer) - strlen(temp_buffer) - 1);
    strncat(temp_buffer, csv_line_buffer, sizeof(temp_buffer) - strlen(temp_buffer) - 1);
    strncpy(csv_line_buffer, temp_buffer, sizeof(csv_line_buffer) - 1);
    csv_line_buffer[sizeof(csv_line_buffer) - 1] = '\0'; // Ensure null termination
  } else {
    fprintf(stderr, "CSV line buffer is full, cannot prepend timestamp and offset.\n");
  }
}

static void log_int_value(byte_array_t name, meas_record_lst_t meas_record) {
  byte_array_t unit = {.buf = (uint8_t *)"", .len = 0};

  if (!csv_wrote_header) {
    if (cmp_str_ba("RRU.PrbTotDl", name) == 0) {
      unit.buf = (uint8_t *)"PRBs";
      unit.len = strlen("PRBs");
    } else if (cmp_str_ba("RRU.PrbTotUl", name) == 0) {
      unit.buf = (uint8_t *)"PRBs";
      unit.len = strlen("PRBs");
    } else if (cmp_str_ba("DRB.PdcpSduVolumeDL", name) == 0) {
      unit.buf = (uint8_t *)"kb";
      unit.len = strlen("kb");
    } else if (cmp_str_ba("DRB.PdcpSduVolumeUL", name) == 0) {
      unit.buf = (uint8_t *)"kb";
      unit.len = strlen("kb");
    } else if (cmp_str_ba("RSRP.Count", name) == 0) {
      unit.buf = (uint8_t *)"";
      unit.len = 0;
    } else {
      unit.buf = (uint8_t *)"";
      unit.len = 0;
    }
    csv_append_name_to_csv_header(name, unit);
  }
  csv_append_int_to_csv_line(meas_record);
  // if (cmp_str_ba("RRU.PrbTotDl", name) == 0) {
  //   printf("RRU.PrbTotDl = %d [PRBs]\n", meas_record.int_val);
  // } else if (cmp_str_ba("RRU.PrbTotUl", name) == 0) {
  //   printf("RRU.PrbTotUl = %d [PRBs]\n", meas_record.int_val);
  // } else if (cmp_str_ba("DRB.PdcpSduVolumeDL", name) == 0) {
  //   printf("DRB.PdcpSduVolumeDL = %d [kb]\n", meas_record.int_val);
  // } else if (cmp_str_ba("DRB.PdcpSduVolumeUL", name) == 0) {
  //   printf("DRB.PdcpSduVolumeUL = %d [kb]\n", meas_record.int_val);
  // } else if (...) {
  // } else {
  //   printf("Measurement Name not yet supported\n");
  // }

  // If the measurement is RSRP.Count and the value is 0, the data is invalid
  if (filter_invalid_rsrp_samples && cmp_str_ba("RSRP.Count", name) == 0) {
    if (meas_record.int_val == 0) {
      filter_current_sample = true;
      printf("\n\tNumber of RSRP measurements was zero, skipping sample to avoid divide by zero.\n\n");
    }
  }
}
static void log_real_value(byte_array_t name, meas_record_lst_t meas_record) {
  byte_array_t unit = {.buf = (uint8_t *)"", .len = 0};

  if (!csv_wrote_header) {
    if (cmp_str_ba("DRB.RlcSduDelayDl", name) == 0) {
      unit.buf = (uint8_t *)"μs";
      unit.len = strlen("μs");
    } else if (cmp_str_ba("DRB.UEThpDl", name) == 0) {
      unit.buf = (uint8_t *)"kbps";
      unit.len = strlen("kbps");
    } else if (cmp_str_ba("DRB.UEThpUl", name) == 0) {
      unit.buf = (uint8_t *)"kbps";
      unit.len = strlen("kbps");
    } else if (cmp_str_ba("RSRP.Mean", name) == 0) {
      unit.buf = (uint8_t *)"dBm";
      unit.len = strlen("dBm");
    }
    csv_append_name_to_csv_header(name, unit);
  }
  csv_append_real_to_csv_line(meas_record);
  // if (cmp_str_ba("DRB.RlcSduDelayDl", name) == 0) {
  //   printf("DRB.RlcSduDelayDl = %.2f [μs]\n", meas_record.real_val);
  // } else if (cmp_str_ba("DRB.UEThpDl", name) == 0) {
  //   printf("DRB.UEThpDl = %.2f [kbps]\n", meas_record.real_val);
  // } else if (cmp_str_ba("DRB.UEThpUl", name) == 0) {
  //   printf("DRB.UEThpUl = %.2f [kbps]\n", meas_record.real_val);
  // } else if (...) {
  // } else {
  //   printf("Measurement Name not yet supported\n");
  // }
}

typedef void (*log_meas_value)(byte_array_t name, meas_record_lst_t meas_record);

static log_meas_value get_meas_value[END_MEAS_VALUE] = {
    log_int_value,
    log_real_value,
    NULL,
};

static void match_meas_name_type(meas_type_t meas_type, meas_record_lst_t meas_record) {
  // Get the value of the Measurement
  get_meas_value[meas_record.value](meas_type.name, meas_record);
}

static void match_id_meas_type(meas_type_t meas_type, meas_record_lst_t meas_record) {
  (void)meas_type;
  (void)meas_record;
  assert(false && "ID Measurement Type not yet supported");
}

typedef void (*check_meas_type)(meas_type_t meas_type, meas_record_lst_t meas_record);

static check_meas_type match_meas_type[END_MEAS_TYPE] = {
    match_meas_name_type,
    match_id_meas_type,
};

static void write_csv_header_to_file() {
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

static void write_csv_line_to_file() {
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

static void log_kpm_measurements(kpm_ind_msg_format_1_t const *msg_frm_1) {
  assert(msg_frm_1->meas_info_lst_len > 0 && "Cannot correctly print measurements");

  // UE Measurements per granularity period
  for (size_t j = 0; j < msg_frm_1->meas_data_lst_len; j++) {
    meas_data_lst_t const data_item = msg_frm_1->meas_data_lst[j];

    for (size_t z = 0; z < data_item.meas_record_len; z++) {
      meas_type_t const meas_type = msg_frm_1->meas_info_lst[z].meas_type;
      meas_record_lst_t const record_item = data_item.meas_record_lst[z];

      match_meas_type[meas_type.type](meas_type, record_item);

      if (data_item.incomplete_flag && *data_item.incomplete_flag == TRUE_ENUM_VALUE)
        printf("Measurement Record not reliable");
    }
  }
  write_csv_header_to_file();

  if (skip_first_sample) {
    printf("Skipping first sample to avoid incorrect initial values.\n");
    memset(csv_line_buffer, 0, sizeof(csv_line_buffer)); // Clean the line buffer
    skip_first_sample = false;
    return;
  }

  if (filter_invalid_rsrp_samples || !filter_current_sample) {
    csv_prepend_ue_id();
    csv_prepend_timestamp();
    write_csv_line_to_file();
  } else {
    // Log an empty measurement row with 25 commas after the 0
    printf("Logging empty measurement row\n");
    memset(csv_line_buffer, 0, sizeof(csv_line_buffer));
    snprintf(csv_line_buffer, sizeof(csv_line_buffer), ",,,,,,,,,,,,,,,,,,,,,,,,,,");
    csv_prepend_timestamp();
    write_csv_line_to_file();

    // Clear the line buffer for the next entry
    memset(csv_line_buffer, 0, sizeof(csv_line_buffer));
  }

  filter_current_sample = false;
  csv_num_rows++;
  printf("Samples collected = %u\n", csv_num_rows);
}

static void sm_cb_kpm(sm_ag_if_rd_t const *rd) {
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0);

  // Reading Indication Message Format 3
  kpm_ind_data_t const *ind = &rd->ind.kpm.ind;
  kpm_ric_ind_hdr_format_1_t const *hdr_frm_1 = &ind->hdr.kpm_ric_ind_hdr_format_1;
  kpm_ind_msg_format_3_t const *msg_frm_3 = &ind->msg.frm_3;

  int64_t const now = time_now_us();
  static int counter = 1;
  {
    lock_guard(&mtx);

    printf("\n%7d KPM ind_msg latency = %ld [μs]\n", counter, now - hdr_frm_1->collectStartTime); // xApp <-> E2 Node

    // Reported list of measurements per UE
    for (size_t i = 0; i < msg_frm_3->ue_meas_report_lst_len; i++) {
      // log UE ID
      ue_id_e2sm_t const ue_id_e2sm = msg_frm_3->meas_report_per_ue[i].ue_meas_report_lst;
      ue_id_e2sm_e const type = ue_id_e2sm.type;
      log_ue_id_e2sm[type](ue_id_e2sm);

      // log measurements
      log_kpm_measurements(&msg_frm_3->meas_report_per_ue[i].ind_msg_format_1);
    }
    counter++;
  }
  prev_now = now / 1000;
}

static test_info_lst_t filter_predicate(test_cond_type_e type, test_cond_e cond, int value) {
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
  const size_t len_nssai = 1;
  dst.test_cond_value->octet_string_value->len = len_nssai;
  dst.test_cond_value->octet_string_value->buf = calloc(len_nssai, sizeof(uint8_t));
  assert(dst.test_cond_value->octet_string_value->buf != NULL && "Memory exhausted");
  dst.test_cond_value->octet_string_value->buf[0] = value;

  return dst;
}

static label_info_lst_t fill_kpm_label(void) {
  label_info_lst_t label_item = {0};

  label_item.noLabel = ecalloc(1, sizeof(enum_value_e));
  *label_item.noLabel = TRUE_ENUM_VALUE;

  return label_item;
}

static kpm_act_def_format_1_t fill_act_def_frm_1(ric_report_style_item_t const *report_item) {
  assert(report_item != NULL);

  kpm_act_def_format_1_t ad_frm_1 = {0};

  size_t const sz = report_item->meas_info_for_action_lst_len;

  // [1, 65535]
  ad_frm_1.meas_info_lst_len = sz;
  ad_frm_1.meas_info_lst = calloc(sz, sizeof(meas_info_format_1_lst_t));
  assert(ad_frm_1.meas_info_lst != NULL && "Memory exhausted");

  for (size_t i = 0; i < sz; i++) {
    meas_info_format_1_lst_t *meas_item = &ad_frm_1.meas_info_lst[i];
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

static kpm_act_def_t fill_report_style_4(ric_report_style_item_t const *report_item) {
  assert(report_item != NULL);
  assert(report_item->act_def_format_type == FORMAT_4_ACTION_DEFINITION);

  kpm_act_def_t act_def = {.type = FORMAT_4_ACTION_DEFINITION};

  // Fill matching condition
  // [1, 32768]
  act_def.frm_4.matching_cond_lst_len = 1;
  act_def.frm_4.matching_cond_lst = calloc(act_def.frm_4.matching_cond_lst_len, sizeof(matching_condition_format_4_lst_t));
  assert(act_def.frm_4.matching_cond_lst != NULL && "Memory exhausted");
  // Filter connected UEs by S-NSSAI criteria
  test_cond_type_e const type = S_NSSAI_TEST_COND_TYPE; // CQI_TEST_COND_TYPE
  test_cond_e const condition = EQUAL_TEST_COND;        // GREATERTHAN_TEST_COND
  int const value = 1;
  act_def.frm_4.matching_cond_lst[0].test_info_lst = filter_predicate(type, condition, value);

  // Fill Action Definition Format 1
  // 8.2.1.2.1
  act_def.frm_4.action_def_format_1 = fill_act_def_frm_1(report_item);

  return act_def;
}

typedef kpm_act_def_t (*fill_kpm_act_def)(ric_report_style_item_t const *report_item);

static fill_kpm_act_def get_kpm_act_def[END_RIC_SERVICE_REPORT] = {
    NULL,
    NULL,
    NULL,
    fill_report_style_4,
    NULL,
};

static kpm_sub_data_t gen_kpm_subs(kpm_ran_function_def_t const *ran_func) {
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
  ric_report_style_item_t *const report_item = &ran_func->ric_report_style_list[0];
  ric_service_report_e const report_style_type = report_item->report_style_type;
  *kpm_sub.ad = get_kpm_act_def[report_style_type](report_item);

  return kpm_sub;
}

static bool eq_sm(sm_ran_function_t const *elem, int const id) {
  if (elem->id == id)
    return true;

  return false;
}

static size_t find_sm_idx(sm_ran_function_t *rf, size_t sz, bool (*f)(sm_ran_function_t const *, int const), int const id) {
  for (size_t i = 0; i < sz; i++) {
    if (f(&rf[i], id))
      return i;
  }

  assert(0 != 0 && "SM ID could not be found in the RAN Function List");
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
    fprintf(stderr, "Error: The file path must end with '.csv'.\n");
    return EXIT_FAILURE;
  }

  char *endptr = NULL;
  long val = strtol(argv[2], &endptr, 10);
  if (*endptr != '\0' || val <= 0) {
    fprintf(stderr, "Invalid period_ms value: '%s'. Must be a positive integer.\n", argv[2]);
    return EXIT_FAILURE;
  }
  // Cast to uint64_t and override the global period_ms
  *((uint64_t *)&period_ms) = (uint64_t)val;

  csv_wrote_header = false;
  byte_array_t timestamp_name = {.buf = (uint8_t *)"Time", .len = strlen("Time")};
  byte_array_t timestamp_unit = {.buf = (uint8_t *)"UNIX ms", .len = strlen("UNIX ms")};
  csv_append_name_to_csv_header(timestamp_name, timestamp_unit);
  byte_array_t offset_name = {.buf = (uint8_t *)"Reporting Time Offset", .len = strlen("Reporting Time Offset")};
  byte_array_t offset_unit = {.buf = (uint8_t *)"ms", .len = strlen("ms")};
  csv_append_name_to_csv_header(offset_name, offset_unit);
  byte_array_t ue_id_name = {.buf = (uint8_t *)"UE ID", .len = strlen("UE ID")};
  byte_array_t ue_id_unit = {.buf = (uint8_t *)"", .len = 0};
  csv_append_name_to_csv_header(ue_id_name, ue_id_unit);

  fr_args_t args = init_fr_args(argc, argv);

  // Init the xApp
  init_xapp_api(&args);
  sleep(1);

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  defer({ free_e2_node_arr_xapp(&nodes); });

  assert(nodes.len > 0);

  printf("Connected E2 nodes = %d\n", nodes.len);

  pthread_mutexattr_t attr = {0};
  int rc = pthread_mutex_init(&mtx, &attr);
  assert(rc == 0);

  sm_ans_xapp_t *hndl = calloc(nodes.len, sizeof(sm_ans_xapp_t));
  assert(hndl != NULL);

  ////////////
  // START KPM
  ////////////
  int const KPM_ran_function = 2;

  for (size_t i = 0; i < nodes.len; ++i) {
    e2_node_connected_xapp_t *n = &nodes.n[i];

    size_t const idx = find_sm_idx(n->rf, n->len_rf, eq_sm, KPM_ran_function);
    assert(n->rf[idx].defn.type == KPM_RAN_FUNC_DEF_E && "KPM is not the received RAN Function");
    // if REPORT Service is supported by E2 node, send SUBSCRIPTION
    // e.g. OAI CU-CP
    if (n->rf[idx].defn.kpm.ric_report_style_list != NULL) {
      // Generate KPM SUBSCRIPTION message
      kpm_sub_data_t kpm_sub = gen_kpm_subs(&n->rf[idx].defn.kpm);

      hndl[i] = report_sm_xapp_api(&n->id, KPM_ran_function, &kpm_sub, sm_cb_kpm);
      assert(hndl[i].success == true);

      free_kpm_sub_data(&kpm_sub);
    }
  }
  ////////////
  // END KPM
  ////////////

  xapp_wait_end_api();

  for (int i = 0; i < nodes.len; ++i) {
    // Remove the handle previously returned
    if (hndl[i].success == true)
      rm_report_sm_xapp_api(hndl[i].u.handle);
  }
  free(hndl);

  // Stop the xApp
  while (try_stop_xapp_api() == false)
    usleep(1000);

  printf("Test xApp run SUCCESSFULLY\n");
}
