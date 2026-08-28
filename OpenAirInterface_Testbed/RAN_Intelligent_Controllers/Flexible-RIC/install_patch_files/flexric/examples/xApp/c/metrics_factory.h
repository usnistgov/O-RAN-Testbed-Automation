#ifndef METRICS_FACTORY_H
#define METRICS_FACTORY_H

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../../../src/xApp/e42_xapp_api.h"

#define MAX_E2_NODES 16
#define KPM_CELL_NODE_ATTRIBUTION 1

typedef struct
{
  char node_id_str[256];
  uint32_t last_ss_rsrp_dist[128];
  uint32_t last_ss_sinr_dist[128];
  bool ss_rsrp_initialized;
  bool ss_sinr_initialized;
} e2_node_dist_state_t;

typedef struct
{
  double mean;
  double min;
  double q1;     // Removal candidate
  double median; // Removal candidate
  double q3;     // Removal candidate
  double max;
  uint32_t count;
} dist_metrics_t;

typedef struct
{
  char name[128];
  char unit[16];
  // 0 for int, 1 for real
  int value_type;
  int int_val;
  double real_val;
} factory_metric_t;

typedef struct
{
  factory_metric_t *metrics;
  size_t count;
} factory_metrics_array_t;

void format_e2_node_id(char *dst, size_t dst_len, const global_e2_node_id_t *node_id);
void format_kpm_cell_node_id(char *dst, size_t dst_len, const global_e2_node_id_t *node_id);
void kpm_set_e2_node_topology(const e2_node_arr_xapp_t *nodes);

static inline double ss_sinr_level_representative_db(uint32_t level) {
  // 38.133, Table 10.1.16.1-1: SS-SINR and CSI-SINR measurement report mapping
  assert(level < 128);
  return level == 0 ? -23.5 : ((double)level - 47.0) / 2.0;
}

e2_node_dist_state_t *get_dist_state(const char *e2_id);

int get_percentile_val(uint32_t *dist, size_t index);
double get_sinr_percentile_val(uint32_t *dist, size_t index);

bool compute_rsrp_metrics(const char *node_id, const uint32_t *current_dist, size_t limit, dist_metrics_t *out_metrics);
bool compute_sinr_metrics(const char *node_id, const uint32_t *current_dist, size_t limit, dist_metrics_t *out_metrics);

factory_metrics_array_t process_metric_factory(const char *node_id, const char *metric_name, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start);
factory_metrics_array_t describe_metric_factory(const char *metric_name);

bool kpm_merge_format_1_indications(const kpm_ind_msg_format_1_t *du, const kpm_ind_msg_format_1_t *cell,
                                    kpm_ind_msg_format_1_t *merged);
bool kpm_merge_ue_measurements(const meas_report_per_ue_t *du, const meas_report_per_ue_t *cu,
                               meas_report_per_ue_t *merged);

void free_factory_metrics(factory_metrics_array_t *arr);

void format_meas_record_array(char *arr_str, size_t max_len, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start);

void populate_label_info(meas_info_format_1_lst_t *meas_item);

typedef struct {
  uint64_t period_ms;
  uint8_t sst;
  uint32_t sd;
  uint32_t ue_wait_ms;
  uint32_t report_style_mask;
} kpm_subscription_config_t;

typedef struct {
  sm_ans_xapp_t **handles;
  size_t *handle_counts;
  size_t node_count;
} kpm_subscription_set_t;

typedef struct {
  void (*begin_ue)(void *context, const ue_id_e2sm_t *ue_id);
  void (*measurement)(void *context, const meas_type_t *meas_type, const label_info_lst_t *label,
                      const meas_record_lst_t *record);
  void (*end_ue)(void *context, bool incomplete);
} kpm_format_2_visitor_t;

void kpm_remember_ues(const global_e2_node_id_t *node_id, const kpm_ind_msg_t *msg);
void kpm_visit_format_2(const kpm_ind_msg_format_2_t *msg, const kpm_format_2_visitor_t *visitor, void *context);
sm_ran_function_t *kpm_find_ran_function(e2_node_connected_xapp_t *node, uint32_t ran_function_id);
kpm_subscription_set_t kpm_subscribe_report_styles(const e2_node_arr_xapp_t *nodes, uint32_t ran_function_id,
                                                   kpm_subscription_config_t config, sm_cb callback);
void kpm_unsubscribe_report_styles(kpm_subscription_set_t *subscriptions);
void kpm_reset_ue_registry(void);

#endif // METRICS_FACTORY_H
