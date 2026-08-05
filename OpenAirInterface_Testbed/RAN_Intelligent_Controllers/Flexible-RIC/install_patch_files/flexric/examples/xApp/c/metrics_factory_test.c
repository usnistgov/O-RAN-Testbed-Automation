#include "metrics_factory.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(condition)                                                                                               \
  do {                                                                                                                 \
    if (!(condition)) {                                                                                                \
      fprintf(stderr, "CHECK failed at %s:%d: %s\n", __FILE__, __LINE__, #condition);                                  \
      return EXIT_FAILURE;                                                                                             \
    }                                                                                                                  \
  } while (0)

static bool close_enough(double actual, double expected) {
  return fabs(actual - expected) < 1e-9;
}

static void init_distribution_records(label_info_lst_t labels[128], uint16_t bins[128], meas_record_lst_t records[128],
                                      bool reverse_bins) {
  memset(labels, 0, 128 * sizeof(*labels));
  memset(records, 0, 128 * sizeof(*records));
  for (size_t i = 0; i < 128; i++) {
    bins[i] = reverse_bins ? 127 - i : i;
    labels[i].distBinX = &bins[i];
    records[i].value = 0;
  }
}

static kpm_ind_msg_format_1_t make_format_1_test_message(const char *name, meas_record_lst_t record, bool incomplete) {
  kpm_ind_msg_format_1_t msg = {0};
  msg.meas_info_lst_len = 1;
  msg.meas_info_lst = calloc(1, sizeof(*msg.meas_info_lst));
  msg.meas_info_lst[0].meas_type.type = NAME_MEAS_TYPE;
  msg.meas_info_lst[0].meas_type.name = cp_str_to_ba(name);
  msg.meas_info_lst[0].label_info_lst_len = 1;
  msg.meas_info_lst[0].label_info_lst = calloc(1, sizeof(*msg.meas_info_lst[0].label_info_lst));
  msg.meas_data_lst_len = 1;
  msg.meas_data_lst = calloc(1, sizeof(*msg.meas_data_lst));
  msg.meas_data_lst[0].meas_record_len = 1;
  msg.meas_data_lst[0].meas_record_lst = calloc(1, sizeof(*msg.meas_data_lst[0].meas_record_lst));
  msg.meas_data_lst[0].meas_record_lst[0] = record;
  if (incomplete) {
    msg.meas_data_lst[0].incomplete_flag = calloc(1, sizeof(*msg.meas_data_lst[0].incomplete_flag));
    *msg.meas_data_lst[0].incomplete_flag = TRUE_ENUM_VALUE;
  }
  return msg;
}

int main(void) {
  uint64_t du_id = 1;
  uint64_t second_du_id = 2;
  e2_node_connected_xapp_t topology_nodes[3] = {
      {.id = {.type = ngran_gNB_CU, .plmn = {.mcc = 1, .mnc = 1, .mnc_digit_len = 2}, .nb_id = {.nb_id = 3584}}},
      {.id = {.type = ngran_gNB_DU,
              .plmn = {.mcc = 1, .mnc = 1, .mnc_digit_len = 2},
              .nb_id = {.nb_id = 3584},
              .cu_du_id = &du_id}},
      {.id = {.type = ngran_gNB_DU,
              .plmn = {.mcc = 1, .mnc = 1, .mnc_digit_len = 2},
              .nb_id = {.nb_id = 3584},
              .cu_du_id = &second_du_id}},
  };
  e2_node_arr_xapp_t topology = {.len = 2, .n = topology_nodes};
  char node_id_str[32];
  kpm_set_e2_node_topology(&topology);
  format_kpm_cell_node_id(node_id_str, sizeof(node_id_str), &topology_nodes[0].id);
  CHECK(strcmp(node_id_str, "DU:1") == 0);

  topology.len = 3;
  kpm_set_e2_node_topology(&topology);
  format_kpm_cell_node_id(node_id_str, sizeof(node_id_str), &topology_nodes[0].id);
  CHECK(strcmp(node_id_str, "CU:3584") == 0);

  CHECK(ss_sinr_level_representative_db(0) == -23.5);
  CHECK(ss_sinr_level_representative_db(1) == -23.0);
  CHECK(ss_sinr_level_representative_db(125) == 39.0);
  CHECK(ss_sinr_level_representative_db(126) == 39.5);
  CHECK(ss_sinr_level_representative_db(127) == 40.0);

  uint32_t direct_dist[128] = {0};
  dist_metrics_t direct_metrics;
  CHECK(!compute_sinr_metrics("CU:direct", direct_dist, 128, &direct_metrics));

  direct_dist[1] = 1;
  direct_dist[3] = 3;
  CHECK(compute_sinr_metrics("CU:direct", direct_dist, 128, &direct_metrics));
  const double expected_mean = 10.0 * log10((pow(10.0, -23.0 / 10.0) + 3.0 * pow(10.0, -22.0 / 10.0)) / 4.0);
  CHECK(close_enough(direct_metrics.mean, expected_mean));
  CHECK(direct_metrics.min == -23.0);
  CHECK(direct_metrics.q1 == -23.0);     // Removal candidate
  CHECK(direct_metrics.median == -22.0); // Removal candidate
  CHECK(direct_metrics.q3 == -22.0);     // Removal candidate
  CHECK(direct_metrics.max == -22.0);
  CHECK(direct_metrics.count == 4);

  CHECK(!compute_sinr_metrics("CU:direct", direct_dist, 128, &direct_metrics));

  memset(direct_dist, 0, sizeof(direct_dist));
  direct_dist[3] = 1;
  CHECK(compute_sinr_metrics("CU:direct", direct_dist, 128, &direct_metrics));
  CHECK(direct_metrics.mean == -22.0);
  CHECK(direct_metrics.min == -22.0);
  CHECK(direct_metrics.max == -22.0);
  CHECK(direct_metrics.count == 1);

  label_info_lst_t labels[128];
  uint16_t bins[128];
  meas_record_lst_t records[128];
  init_distribution_records(labels, bins, records, true);

  factory_metrics_array_t generated = process_metric_factory("CU:factory", "MR.NRScSSSINR", labels, 128, records, 0);
  CHECK(generated.count == 0);

  records[0].int_val = 2; // Record zero is labeled distBinX=127, not distBinX=0
  generated = process_metric_factory("CU:factory", "MR.NRScSSSINR", labels, 128, records, 0);
  CHECK(generated.count == 7);
  CHECK(strcmp(generated.metrics[0].name, "SINR.Mean") == 0);
  CHECK(generated.metrics[0].real_val == 40.0);
  CHECK(generated.metrics[1].real_val == 40.0);
  CHECK(generated.metrics[2].real_val == 40.0);
  CHECK(generated.metrics[3].real_val == 40.0);
  CHECK(generated.metrics[4].real_val == 40.0);
  CHECK(generated.metrics[5].real_val == 40.0);
  CHECK(strcmp(generated.metrics[6].name, "SINR.Count") == 0);
  CHECK(generated.metrics[6].int_val == 2);
  free_factory_metrics(&generated);

  generated = process_metric_factory("CU:factory", "MR.NRScSSSINR", labels, 128, records, 0);
  CHECK(generated.count == 0);

  generated = process_metric_factory("CU:partial", "MR.NRScSSSINR", labels, 127, records, 0);
  CHECK(generated.count == 0);

  bins[1] = bins[0];
  generated = process_metric_factory("CU:duplicate", "MR.NRScSSSINR", labels, 128, records, 0);
  CHECK(generated.count == 0);

  const meas_record_lst_t du_record = {.value = INTEGER_MEAS_VALUE, .int_val = 7};
  const meas_record_lst_t cell_record = {.value = REAL_MEAS_VALUE, .real_val = 8.5};
  kpm_ind_msg_format_1_t du_msg = make_format_1_test_message("DU.Metric", du_record, false);
  kpm_ind_msg_format_1_t cell_msg = make_format_1_test_message("MR.NRScSSSINR", cell_record, true);
  kpm_ind_msg_format_1_t merged = {0};
  CHECK(kpm_merge_format_1_indications(&du_msg, &cell_msg, &merged));
  CHECK(merged.meas_info_lst_len == 2);
  CHECK(merged.meas_data_lst_len == 1);
  CHECK(merged.meas_data_lst[0].meas_record_len == 2);
  CHECK(merged.meas_data_lst[0].meas_record_lst[0].int_val == 7);
  CHECK(merged.meas_data_lst[0].meas_record_lst[1].real_val == 8.5);
  CHECK(merged.meas_data_lst[0].incomplete_flag != NULL);
  CHECK(*merged.meas_data_lst[0].incomplete_flag == TRUE_ENUM_VALUE);
  char *merged_name = cp_ba_to_str(merged.meas_info_lst[1].meas_type.name);
  CHECK(strcmp(merged_name, "MR.NRScSSSINR") == 0);
  free(merged_name);
  free_kpm_ind_msg_frm_1(&du_msg);
  free_kpm_ind_msg_frm_1(&cell_msg);
  free_kpm_ind_msg_frm_1(&merged);

  kpm_reset_ue_registry();

  return EXIT_SUCCESS;
}
