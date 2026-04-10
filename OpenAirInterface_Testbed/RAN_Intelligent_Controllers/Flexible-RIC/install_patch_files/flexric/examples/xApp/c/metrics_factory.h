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
} e2_node_rsrp_state_t;

typedef struct
{
  double mean;
  double min;
  double q1;
  double median;
  double q3;
  double max;
  uint32_t count;
} rsrp_metrics_t;

typedef struct
{
  char name[128];
  // 0 for int, 1 for real
  int value_type;
  int int_val;
  double real_val;
} derived_metric_t;

typedef struct
{
  derived_metric_t *metrics;
  size_t count;
} derived_metrics_array_t;

e2_node_rsrp_state_t *get_rsrp_state(const char *e2_id);

int get_percentile_val(uint32_t *dist, size_t index);

bool compute_rsrp_metrics(const char *node_id, const uint32_t *current_dist, rsrp_metrics_t *out_metrics);

derived_metrics_array_t process_metric_factory(const char *node_id, const char *metric_name, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start);

void free_derived_metrics(derived_metrics_array_t *arr);

void format_meas_record_array(char *arr_str, size_t max_len, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start);

void populate_label_info(meas_info_format_1_lst_t *meas_item);

#endif // METRICS_FACTORY_H
