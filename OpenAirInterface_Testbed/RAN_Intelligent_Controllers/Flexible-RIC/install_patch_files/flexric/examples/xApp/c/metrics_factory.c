#include "metrics_factory.h"
#include "../../../src/util/alg_ds/alg/murmur_hash_32.h"
#include "../../../src/util/alg_ds/ds/assoc_container/assoc_generic.h"
#include "../../../src/util/e.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>

static e2_node_rsrp_state_t rsrp_state[MAX_E2_NODES] = {0};
static int rsrp_state_count = 0;

e2_node_rsrp_state_t *get_rsrp_state(const char *e2_id)
{
  for (int i = 0; i < rsrp_state_count; i++)
  {
    if (strncmp(rsrp_state[i].node_id_str, e2_id, sizeof(rsrp_state[i].node_id_str)) == 0)
    {
      return &rsrp_state[i];
    }
  }

  if (rsrp_state_count < MAX_E2_NODES)
  {
    strncpy(rsrp_state[rsrp_state_count].node_id_str, e2_id, sizeof(rsrp_state[rsrp_state_count].node_id_str) - 1);
    return &rsrp_state[rsrp_state_count++];
  }

  return NULL;
}

int get_percentile_val(uint32_t *dist, size_t index)
{
  uint32_t cumulative = 0;
  for (int i = 0; i < 128; i++)
  {
    cumulative += dist[i];
    if (cumulative > index)
    {
      return -156 + i;
    }
  }
  return -156 + 127;
}

bool compute_rsrp_metrics(const char *node_id, const uint32_t *current_dist, rsrp_metrics_t *out_metrics)
{
  if (!out_metrics)
    return false;
  out_metrics->mean = 0;
  out_metrics->min = 0;
  out_metrics->q1 = 0;
  out_metrics->median = 0;
  out_metrics->q3 = 0;
  out_metrics->max = 0;
  out_metrics->count = 0;

  e2_node_rsrp_state_t *state = get_rsrp_state(node_id);
  if (!state)
    return false;

  uint32_t diff_dist[128] = {0};
  uint32_t total_count = 0;

  for (int i = 0; i < 128; i++)
  {
    if (current_dist[i] >= state->last_ss_rsrp_dist[i])
    {
      diff_dist[i] = current_dist[i] - state->last_ss_rsrp_dist[i];
    }
    else
    {
      diff_dist[i] = current_dist[i];
    }
    total_count += diff_dist[i];
    state->last_ss_rsrp_dist[i] = current_dist[i];
  }

  if (total_count == 0)
  {
    return true;
  }

  double sum = 0;
  int min_val = 9999, max_val = -9999;
  for (int i = 0; i < 128; i++)
  {
    if (diff_dist[i] > 0)
    {
      int dbm_val = -156 + i;
      sum += (double)dbm_val * diff_dist[i];
      if (dbm_val < min_val)
        min_val = dbm_val;
      if (dbm_val > max_val)
        max_val = dbm_val;
    }
  }

  double q1, median, q3;
  size_t n = total_count;

  size_t q1_idx = n / 4;
  if (n % 4 == 0 && n > 0 && q1_idx > 0)
  {
    q1 = (get_percentile_val(diff_dist, q1_idx - 1) + get_percentile_val(diff_dist, q1_idx)) / 2.0;
  }
  else
  {
    q1 = get_percentile_val(diff_dist, q1_idx);
  }

  size_t med_idx = n / 2;
  if (n % 2 == 0 && n > 0 && med_idx > 0)
  {
    median = (get_percentile_val(diff_dist, med_idx - 1) + get_percentile_val(diff_dist, med_idx)) / 2.0;
  }
  else
  {
    median = get_percentile_val(diff_dist, med_idx);
  }

  size_t q3_idx = (3 * n) / 4;
  if (n % 4 == 0 && n > 0 && q3_idx > 0)
  {
    q3 = (get_percentile_val(diff_dist, q3_idx - 1) + get_percentile_val(diff_dist, q3_idx)) / 2.0;
  }
  else
  {
    q3 = get_percentile_val(diff_dist, q3_idx);
  }

  out_metrics->mean = sum / total_count;
  out_metrics->min = (double)min_val;
  out_metrics->q1 = q1;
  out_metrics->median = median;
  out_metrics->q3 = q3;
  out_metrics->max = (double)max_val;
  out_metrics->count = total_count;

  return true;
}

derived_metrics_array_t process_metric_factory(const char *node_id, const char *metric_name, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start)
{
  (void)label_info_lst;
  derived_metrics_array_t ret = {0};

  // Derive RSRP.Mean, RSRP.Minimum, RSRP.Quartile1, RSRP.Median, RSRP.Quartile3, RSRP.Maximum, and RSRP.Count from L1M.SS-RSRP
  if (strcmp(metric_name, "L1M.SS-RSRP") == 0 && label_info_lst_len == 128)
  {
    uint32_t current_dist[128] = {0};
    for (size_t i = 0; i < 128; i++)
    {
      if (meas_record_lst[rec_idx_start + i].value == 0)
        current_dist[i] = meas_record_lst[rec_idx_start + i].int_val;
    }

    rsrp_metrics_t metrics;
    if (compute_rsrp_metrics(node_id, current_dist, &metrics) && metrics.count > 0)
    {
      ret.count = 7;
      ret.metrics = calloc(ret.count, sizeof(derived_metric_t));

      snprintf(ret.metrics[0].name, sizeof(ret.metrics[0].name), "RSRP.Mean");
      ret.metrics[0].value_type = 1;
      ret.metrics[0].real_val = metrics.mean;

      snprintf(ret.metrics[1].name, sizeof(ret.metrics[1].name), "RSRP.Minimum");
      ret.metrics[1].value_type = 1;
      ret.metrics[1].real_val = metrics.min;

      snprintf(ret.metrics[2].name, sizeof(ret.metrics[2].name), "RSRP.Quartile1");
      ret.metrics[2].value_type = 1;
      ret.metrics[2].real_val = metrics.q1;

      snprintf(ret.metrics[3].name, sizeof(ret.metrics[3].name), "RSRP.Median");
      ret.metrics[3].value_type = 1;
      ret.metrics[3].real_val = metrics.median;

      snprintf(ret.metrics[4].name, sizeof(ret.metrics[4].name), "RSRP.Quartile3");
      ret.metrics[4].value_type = 1;
      ret.metrics[4].real_val = metrics.q3;

      snprintf(ret.metrics[5].name, sizeof(ret.metrics[5].name), "RSRP.Maximum");
      ret.metrics[5].value_type = 1;
      ret.metrics[5].real_val = metrics.max;

      snprintf(ret.metrics[6].name, sizeof(ret.metrics[6].name), "RSRP.Count");
      ret.metrics[6].value_type = 0;
      ret.metrics[6].int_val = metrics.count;
    }
  }

  return ret;
}

void free_derived_metrics(derived_metrics_array_t *arr)
{
  if (arr->metrics)
  {
    free(arr->metrics);
    arr->metrics = NULL;
  }
  arr->count = 0;
}

void format_meas_record_array(char *arr_str, size_t max_len, const label_info_lst_t *label_info_lst, size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst, size_t rec_idx_start)
{
  size_t arr_len = 0;
  arr_str[0] = '\0';
  uint32_t last_x = 0, last_y = 0;
  bool has_y = label_info_lst_len > 0 && label_info_lst[0].distBinY != NULL;
  bool has_z = label_info_lst_len > 0 && label_info_lst[0].distBinZ != NULL;

  size_t rec_idx = rec_idx_start;

  for (size_t z = 0; z < label_info_lst_len; z++)
  {
    const label_info_lst_t label_info = label_info_lst[z];
    const meas_record_lst_t record_item = meas_record_lst[rec_idx++];

    uint32_t cur_x = label_info.distBinX ? *label_info.distBinX : 0;
    uint32_t cur_y = label_info.distBinY ? *label_info.distBinY : 0;

    int n = 0;
    if (z == 0)
    {
      if (has_z)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[[[");
      else if (has_y)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[[");
      else
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[");
    }
    else
    {
      if (has_z && cur_x != last_x)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "]], [[");
      else if (has_z && cur_y != last_y)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "], [");
      else if (has_y && cur_x != last_x)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "], [");
      else
        n = snprintf(arr_str + arr_len, max_len - arr_len, ", ");
    }
    if (n > 0)
      arr_len += ((size_t)n < max_len - arr_len) ? (size_t)n : max_len - arr_len - 1;

    if (record_item.value == 0)
      n = snprintf(arr_str + arr_len, max_len - arr_len, "%d", record_item.int_val);
    else if (record_item.value == 1)
      n = snprintf(arr_str + arr_len, max_len - arr_len, "%.2f", record_item.real_val);
    else
      n = snprintf(arr_str + arr_len, max_len - arr_len, "null");

    if (n > 0)
      arr_len += ((size_t)n < max_len - arr_len) ? (size_t)n : max_len - arr_len - 1;

    last_x = cur_x;
    last_y = cur_y;
  }

  if (label_info_lst_len > 0)
  {
    int n = 0;
    if (has_z)
      n = snprintf(arr_str + arr_len, max_len - arr_len, "]]]");
    else if (has_y)
      n = snprintf(arr_str + arr_len, max_len - arr_len, "]]");
    else
      n = snprintf(arr_str + arr_len, max_len - arr_len, "]");
    if (n > 0)
      arr_len += ((size_t)n < max_len - arr_len) ? (size_t)n : max_len - arr_len - 1;
  }
}

static label_info_lst_t fill_kpm_label(void)
{
  label_info_lst_t label_item = {0};
  label_item.noLabel = ecalloc(1, sizeof(enum_value_e));
  *label_item.noLabel = TRUE_ENUM_VALUE;
  return label_item;
}

static label_info_lst_t fill_distribution_bin_1d_label(const uint32_t x)
{
  label_info_lst_t label_item = {0};
  label_item.distBinX = calloc(1, sizeof(uint32_t));
  assert(label_item.distBinX != NULL);
  *label_item.distBinX = x;
  return label_item;
}

static label_info_lst_t fill_distribution_bin_label(const uint32_t x, const uint32_t y, const uint32_t z)
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

void populate_label_info(meas_info_format_1_lst_t *meas_item)
{
  if (cmp_str_ba("CARR.PDSCHMCSDist", meas_item->meas_type.name) == 0)
  {
    /// 1-8 RI, 1-3 MCS table, 0-31 MCS value
    meas_item->label_info_lst_len = 8 * 3 * 32;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    size_t idx = 0;
    for (uint32_t x = 1; x <= 8; x++)
    {
      for (uint32_t y = 1; y <= 3; y++)
      {
        for (uint32_t z = 0; z <= 31; z++)
        {
          meas_item->label_info_lst[idx++] = fill_distribution_bin_label(x, y, z);
        }
      }
    }
  }
  else if (cmp_str_ba("L1M.SS-RSRP", meas_item->meas_type.name) == 0)
  {
    meas_item->label_info_lst_len = 128;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    for (uint32_t x = 1; x <= 128; x++)
    {
      meas_item->label_info_lst[x - 1] = fill_distribution_bin_1d_label(x);
    }
  }
  else
  {
    meas_item->label_info_lst_len = 1;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    meas_item->label_info_lst[0] = fill_kpm_label();
  }
}
