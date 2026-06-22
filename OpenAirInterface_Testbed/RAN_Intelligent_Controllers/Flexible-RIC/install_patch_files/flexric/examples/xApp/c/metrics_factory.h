#ifndef METRICS_FACTORY_H
#define METRICS_FACTORY_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "../../../src/xApp/e42_xapp_api.h"

#define MAX_E2_NODES 16

typedef struct
{
  char node_id_str[256];
  uint32_t last_ss_rsrp_dist[128];
  uint32_t last_ss_sinr_dist[128];
} e2_node_dist_state_t;

typedef struct
{
  double mean;
  double min;
  double max;
  uint32_t count;
} dist_metrics_t;

typedef struct
{
  char name[128];
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

e2_node_dist_state_t *get_dist_state(const char *e2_id);

int get_percentile_val(uint32_t *dist, size_t index);
double get_sinr_percentile_val(uint32_t *dist, size_t index);

bool compute_rsrp_metrics(const char *node_id, const uint32_t *current_dist, size_t limit, dist_metrics_t *out_metrics);
bool compute_sinr_metrics(const char *node_id, const uint32_t *current_dist, size_t limit, dist_metrics_t *out_metrics);

factory_metrics_array_t process_metric_factory(const char *node_id, const char *metric_name, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start);

void free_factory_metrics(factory_metrics_array_t *arr);

void format_meas_record_array(char *arr_str, size_t max_len, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start);

void populate_label_info(meas_info_format_1_lst_t *meas_item);

#endif // METRICS_FACTORY_H
