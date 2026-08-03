#include "metrics_factory.h"
#include "../../../src/util/alg_ds/alg/murmur_hash_32.h"
#include "../../../src/util/alg_ds/ds/assoc_container/assoc_generic.h"
#include "../../../src/util/e.h"
#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static e2_node_dist_state_t dist_state[MAX_E2_NODES] = {0};
static int dist_state_count = 0;

void format_e2_node_id(char *dst, size_t dst_len, const global_e2_node_id_t *node_id) {
  assert(dst != NULL);
  assert(dst_len > 0);

  if (node_id == NULL) {
    snprintf(dst, dst_len, "Unknown");
    return;
  }

  const uint64_t id = node_id->cu_du_id != NULL ? *node_id->cu_du_id : (uint64_t)node_id->nb_id.nb_id;
  switch (node_id->type) {
  case ngran_gNB_DU:
    snprintf(dst, dst_len, "DU:%" PRIu64, id);
    break;
  case ngran_gNB_CU:
    snprintf(dst, dst_len, "CU:%" PRIu64, id);
    break;
  case ngran_gNB_CUUP:
    snprintf(dst, dst_len, "CUUP:%" PRIu64, id);
    break;
  case ngran_gNB_CUCP:
    snprintf(dst, dst_len, "CUCP:%" PRIu64, id);
    break;
  default:
    snprintf(dst, dst_len, "gNB:%" PRIu64, id);
    break;
  }
}

e2_node_dist_state_t *get_dist_state(const char *e2_id) {
  for (int i = 0; i < dist_state_count; i++) {
    if (strncmp(dist_state[i].node_id_str, e2_id, sizeof(dist_state[i].node_id_str)) == 0) {
      return &dist_state[i];
    }
  }

  if (dist_state_count < MAX_E2_NODES) {
    strncpy(dist_state[dist_state_count].node_id_str, e2_id, sizeof(dist_state[dist_state_count].node_id_str) - 1);
    return &dist_state[dist_state_count++];
  }

  return NULL;
}

double get_sinr_percentile_val(uint32_t *dist, size_t index) {
  uint32_t cumulative = 0;
  for (int i = 0; i < 128; i++) {
    cumulative += dist[i];
    if (cumulative > index) {
      return ss_sinr_level_representative_db(i);
    }
  }
  return ss_sinr_level_representative_db(127);
}

int get_percentile_val(uint32_t *dist, size_t index) {
  uint32_t cumulative = 0;
  for (int i = 0; i < 128; i++) {
    cumulative += dist[i];
    if (cumulative > index) {
      // 38.133, Table 10.1.6.1-1: SS-RSRP and CSI-RSRP measurement report mapping
      return -(156 + 1) + i;
    }
  }
  return -(156 + 1) + 127;
}

bool compute_rsrp_metrics(const char *node_id, const uint32_t *current_dist, size_t limit,
                          dist_metrics_t *out_metrics) {
  if (!out_metrics)
    return false;
  out_metrics->mean = NAN;
  out_metrics->min = NAN;
  out_metrics->q1 = NAN;     // Removal candidate
  out_metrics->median = NAN; // Removal candidate
  out_metrics->q3 = NAN;     // Removal candidate
  out_metrics->max = NAN;
  out_metrics->count = 0;

  e2_node_dist_state_t *state = get_dist_state(node_id);
  if (!state)
    return false;

  uint32_t diff_dist[128] = {0};
  uint32_t total_count = 0;
  uint32_t total_current = 0;

  for (size_t i = 0; i < limit; i++) {
    total_current += current_dist[i];
  }

  if (!state->ss_rsrp_initialized) {
    memcpy(state->last_ss_rsrp_dist, current_dist, limit * sizeof(current_dist[0]));
    state->ss_rsrp_initialized = true;
    return true;
  }

  // Per-UE metrics don't have RSRP; return early
  if (total_current == 0) {
    return true;
  }

  for (size_t i = 0; i < limit; i++) {
    if (current_dist[i] >= state->last_ss_rsrp_dist[i]) {
      diff_dist[i] = current_dist[i] - state->last_ss_rsrp_dist[i];
    } else {
      diff_dist[i] = current_dist[i];
    }
    total_count += diff_dist[i];
    state->last_ss_rsrp_dist[i] = current_dist[i];
  }

  if (total_count == 0) {
    return true;
  }

  double sum = 0;
  int min_val = 9999, max_val = -9999;
  for (size_t i = 0; i < limit; i++) {
    if (diff_dist[i] > 0) {
      // 38.133, Table 10.1.6.1-1: SS-RSRP and CSI-RSRP measurement report mapping
      int dbm_val = -(156 + 1) + i;
      double linear_val = pow(10.0, dbm_val / 10.0);
      sum += linear_val * diff_dist[i];
      if (dbm_val < min_val)
        min_val = dbm_val;
      if (dbm_val > max_val)
        max_val = dbm_val;
    }
  }

  out_metrics->mean = 10.0 * log10(sum / total_count);
  out_metrics->min = (double)min_val;
  out_metrics->q1 = out_metrics->mean;     // Removal candidate
  out_metrics->median = out_metrics->mean; // Removal candidate
  out_metrics->q3 = out_metrics->mean;     // Removal candidate
  out_metrics->max = (double)max_val;
  out_metrics->count = total_count;

  return true;
}

bool compute_sinr_metrics(const char *node_id, const uint32_t *current_dist, size_t limit,
                          dist_metrics_t *out_metrics) {
  if (!out_metrics)
    return false;
  out_metrics->mean = NAN;
  out_metrics->min = NAN;
  out_metrics->q1 = NAN;     // Removal candidate
  out_metrics->median = NAN; // Removal candidate
  out_metrics->q3 = NAN;     // Removal candidate
  out_metrics->max = NAN;
  out_metrics->count = 0;

  e2_node_dist_state_t *state = get_dist_state(node_id);
  if (!state)
    return false;

  uint32_t diff_dist[128] = {0};
  uint32_t total_count = 0;
  uint32_t total_current = 0;

  for (size_t i = 0; i < limit; i++) {
    total_current += current_dist[i];
  }

  if (!state->ss_sinr_initialized) {
    memcpy(state->last_ss_sinr_dist, current_dist, limit * sizeof(current_dist[0]));
    state->ss_sinr_initialized = true;
    return true;
  }

  if (total_current == 0) {
    return true;
  }

  for (size_t i = 0; i < limit; i++) {
    if (current_dist[i] >= state->last_ss_sinr_dist[i]) {
      diff_dist[i] = current_dist[i] - state->last_ss_sinr_dist[i];
    } else {
      diff_dist[i] = current_dist[i];
    }
    total_count += diff_dist[i];
    state->last_ss_sinr_dist[i] = current_dist[i];
  }

  if (total_count == 0) {
    return true;
  }

  double sum = 0;
  double min_val = 9999.0, max_val = -9999.0;
  for (size_t i = 0; i < limit; i++) {
    if (diff_dist[i] > 0) {
      double db_val = ss_sinr_level_representative_db(i);
      double linear_val = pow(10.0, db_val / 10.0);
      sum += linear_val * diff_dist[i];
      if (db_val < min_val)
        min_val = db_val;
      if (db_val > max_val)
        max_val = db_val;
    }
  }

  out_metrics->mean = 10.0 * log10(sum / total_count);
  out_metrics->min = min_val;
  out_metrics->q1 = out_metrics->mean;     // Removal candidate
  out_metrics->median = out_metrics->mean; // Removal candidate
  out_metrics->q3 = out_metrics->mean;     // Removal candidate
  out_metrics->max = max_val;
  out_metrics->count = total_count;

  return true;
}

static factory_metrics_array_t describe_distribution_metrics(const char *prefix, const char *unit) {
  static const char *suffixes[] = {
      "Mean",    "Minimum", "Quartile1", "Median", "Quartile3", // Removal candidate
      "Maximum", "Count",
  };

  factory_metrics_array_t ret = {
      .count = sizeof(suffixes) / sizeof(suffixes[0]),
  };
  ret.metrics = calloc(ret.count, sizeof(*ret.metrics));
  if (ret.metrics == NULL) {
    ret.count = 0;
    return ret;
  }

  for (size_t i = 0; i < ret.count; i++) {
    snprintf(ret.metrics[i].name, sizeof(ret.metrics[i].name), "%s.%s", prefix, suffixes[i]);
    snprintf(ret.metrics[i].unit, sizeof(ret.metrics[i].unit), "%s", i + 1 == ret.count ? "" : unit);
    ret.metrics[i].value_type = i + 1 == ret.count ? 0 : 1;
  }
  return ret;
}

factory_metrics_array_t describe_metric_factory(const char *metric_name) {
  if (strcmp(metric_name, "L1M.SS-RSRP") == 0)
    return describe_distribution_metrics("RSRP", "dBm");
  if (strcmp(metric_name, "MR.NRScSSSINR") == 0)
    return describe_distribution_metrics("SINR", "dB");
  return (factory_metrics_array_t){0};
}

factory_metrics_array_t process_metric_factory(const char *node_id, const char *metric_name,
                                               const label_info_lst_t *label_info_lst, size_t label_info_lst_len,
                                               const meas_record_lst_t *meas_record_lst, size_t rec_idx_start) {
  (void)label_info_lst;
  factory_metrics_array_t ret = {0};

  // Derive RSRP.Mean, RSRP.Minimum, RSRP.Maximum, and RSRP.Count from L1M.SS-RSRP
  if (strcmp(metric_name, "L1M.SS-RSRP") == 0 && label_info_lst_len <= 128) {
    uint32_t current_dist[128] = {0};
    for (size_t i = 0; i < label_info_lst_len; i++) {
      if (meas_record_lst[rec_idx_start + i].value == 0)
        current_dist[i] = meas_record_lst[rec_idx_start + i].int_val;
      else if (meas_record_lst[rec_idx_start + i].value == 1)
        current_dist[i] = (uint32_t)meas_record_lst[rec_idx_start + i].real_val;
    }

    dist_metrics_t metrics;
    if (compute_rsrp_metrics(node_id, current_dist, label_info_lst_len, &metrics)) {
      ret = describe_metric_factory(metric_name);
      assert(ret.count == 7);
      ret.metrics[0].real_val = metrics.mean;
      ret.metrics[1].real_val = metrics.min;
      ret.metrics[2].real_val = metrics.q1;
      ret.metrics[3].real_val = metrics.median;
      ret.metrics[4].real_val = metrics.q3;
      ret.metrics[5].real_val = metrics.max;
      ret.metrics[6].int_val = metrics.count;
    }
  }

  // Derive SINR metrics
  if (strcmp(metric_name, "MR.NRScSSSINR") == 0 && label_info_lst_len <= 128) {
    uint32_t current_dist[128] = {0};
    for (size_t i = 0; i < label_info_lst_len; i++) {
      if (meas_record_lst[rec_idx_start + i].value == 0)
        current_dist[i] = meas_record_lst[rec_idx_start + i].int_val;
      else if (meas_record_lst[rec_idx_start + i].value == 1)
        current_dist[i] = (uint32_t)meas_record_lst[rec_idx_start + i].real_val;
    }

    dist_metrics_t metrics;
    if (compute_sinr_metrics(node_id, current_dist, label_info_lst_len, &metrics)) {
      ret = describe_metric_factory(metric_name);
      assert(ret.count == 7);
      ret.metrics[0].real_val = metrics.mean;
      ret.metrics[1].real_val = metrics.min;
      ret.metrics[2].real_val = metrics.q1;
      ret.metrics[3].real_val = metrics.median;
      ret.metrics[4].real_val = metrics.q3;
      ret.metrics[5].real_val = metrics.max;
      ret.metrics[6].int_val = metrics.count;
    }
  }

  return ret;
}

void free_factory_metrics(factory_metrics_array_t *arr) {
  if (arr->metrics) {
    free(arr->metrics);
    arr->metrics = NULL;
  }
  arr->count = 0;
}

void format_meas_record_array(char *arr_str, size_t max_len, const label_info_lst_t *label_info_lst,
                              size_t label_info_lst_len, const meas_record_lst_t *meas_record_lst,
                              size_t rec_idx_start) {
  size_t arr_len = 0;
  arr_str[0] = '\0';
  uint32_t last_x = 0, last_y = 0;
  bool has_y = label_info_lst_len > 0 && label_info_lst[0].distBinY != NULL;
  bool has_z = label_info_lst_len > 0 && label_info_lst[0].distBinZ != NULL;

  size_t rec_idx = rec_idx_start;

  for (size_t z = 0; z < label_info_lst_len; z++) {
    const label_info_lst_t label_info = label_info_lst[z];
    const meas_record_lst_t record_item = meas_record_lst[rec_idx++];

    uint32_t cur_x = label_info.distBinX ? *label_info.distBinX : 0;
    uint32_t cur_y = label_info.distBinY ? *label_info.distBinY : 0;

    int n = 0;
    if (z == 0) {
      if (has_z)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[[[");
      else if (has_y)
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[[");
      else
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[");
    } else {
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

  if (label_info_lst_len > 0) {
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

static label_info_lst_t fill_kpm_label(void) {
  label_info_lst_t label_item = {0};
  label_item.noLabel = ecalloc(1, sizeof(enum_value_e));
  *label_item.noLabel = TRUE_ENUM_VALUE;
  return label_item;
}

static label_info_lst_t fill_distribution_bin_1d_label(const uint32_t x) {
  label_info_lst_t label_item = {0};
  label_item.distBinX = calloc(1, sizeof(uint32_t));
  assert(label_item.distBinX != NULL);
  *label_item.distBinX = x;
  return label_item;
}

static label_info_lst_t fill_distribution_bin_label(const uint32_t x, const uint32_t y, const uint32_t z) {
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

void populate_label_info(meas_info_format_1_lst_t *meas_item) {
  if (cmp_str_ba("CARR.WBCQIDist", meas_item->meas_type.name) == 0) {
    /// 0-15 CQI, 1-8 RI, 1-3 CQI table
    meas_item->label_info_lst_len = 16 * 8 * 3;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    size_t idx = 0;
    for (uint32_t x = 0; x <= 15; x++) {
      for (uint32_t y = 1; y <= 8; y++) {
        for (uint32_t z = 1; z <= 3; z++) {
          meas_item->label_info_lst[idx++] = fill_distribution_bin_label(x, y, z);
        }
      }
    }
  } else if (cmp_str_ba("CARR.PDSCHMCSDist", meas_item->meas_type.name) == 0) {
    /// 1-8 RI, 1-3 MCS table, 0-31 MCS value
    meas_item->label_info_lst_len = 8 * 3 * 32;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    size_t idx = 0;
    for (uint32_t x = 1; x <= 8; x++) {
      for (uint32_t y = 1; y <= 3; y++) {
        for (uint32_t z = 0; z <= 31; z++) {
          meas_item->label_info_lst[idx++] = fill_distribution_bin_label(x, y, z);
        }
      }
    }
  } else if (cmp_str_ba("CARR.PUSCHMCSDist", meas_item->meas_type.name) == 0) {
    /// 1-8 RI, 1-2 MCS table, 0-31 MCS value
    meas_item->label_info_lst_len = 8 * 2 * 32;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    size_t idx = 0;
    for (uint32_t x = 1; x <= 8; x++) {
      for (uint32_t y = 1; y <= 2; y++) {
        for (uint32_t z = 0; z <= 31; z++) {
          meas_item->label_info_lst[idx++] = fill_distribution_bin_label(x, y, z);
        }
      }
    }
  } else if (cmp_str_ba("L1M.SS-RSRP", meas_item->meas_type.name) == 0) {
    meas_item->label_info_lst_len = 128;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    for (uint32_t x = 0; x < 128; x++) {
      meas_item->label_info_lst[x] = fill_distribution_bin_1d_label(x);
    }
  } else if (cmp_str_ba("MR.NRScSSSINR", meas_item->meas_type.name) == 0) {
    meas_item->label_info_lst_len = 128;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    for (uint32_t x = 0; x < 128; x++) {
      meas_item->label_info_lst[x] = fill_distribution_bin_1d_label(x);
    }
  } else {
    meas_item->label_info_lst_len = 1;
    meas_item->label_info_lst = ecalloc(meas_item->label_info_lst_len, sizeof(label_info_lst_t));
    meas_item->label_info_lst[0] = fill_kpm_label();
  }
}

typedef struct {
  global_e2_node_id_t node_id;
  ue_id_e2sm_t *ues;
  size_t len;
  size_t cap;
} kpm_node_ue_store_t;

static pthread_mutex_t kpm_ue_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t kpm_ue_condition = PTHREAD_COND_INITIALIZER;
static kpm_node_ue_store_t kpm_node_ue_stores[MAX_E2_NODES];
static size_t kpm_node_ue_store_count;

static bool same_kpm_ue_id(const ue_id_e2sm_t *lhs, const ue_id_e2sm_t *rhs) {
  assert(lhs != NULL);
  assert(rhs != NULL);

  if (lhs->type != rhs->type)
    return false;

  if (lhs->type == GNB_DU_UE_ID_E2SM) {
    if (lhs->gnb_du.gnb_cu_ue_f1ap != rhs->gnb_du.gnb_cu_ue_f1ap)
      return false;
    if (lhs->gnb_du.ran_ue_id == NULL || rhs->gnb_du.ran_ue_id == NULL)
      return lhs->gnb_du.ran_ue_id == rhs->gnb_du.ran_ue_id;
    return *lhs->gnb_du.ran_ue_id == *rhs->gnb_du.ran_ue_id;
  }

  return eq_ue_id_e2sm(lhs, rhs);
}

static kpm_node_ue_store_t *get_kpm_node_store(const global_e2_node_id_t *node_id, bool create) {
  assert(node_id != NULL);

  for (size_t i = 0; i < kpm_node_ue_store_count; ++i) {
    if (eq_global_e2_node_id(&kpm_node_ue_stores[i].node_id, node_id))
      return &kpm_node_ue_stores[i];
  }

  if (!create)
    return NULL;

  assert(kpm_node_ue_store_count < MAX_E2_NODES);
  kpm_node_ue_store_t *store = &kpm_node_ue_stores[kpm_node_ue_store_count++];
  store->node_id = cp_global_e2_node_id(node_id);
  return store;
}

static void remember_kpm_ue(const global_e2_node_id_t *node_id, const ue_id_e2sm_t *ue_id) {
  int rc = pthread_mutex_lock(&kpm_ue_mutex);
  assert(rc == 0);

  kpm_node_ue_store_t *store = get_kpm_node_store(node_id, true);
  for (size_t i = 0; i < store->len; ++i) {
    if (same_kpm_ue_id(&store->ues[i], ue_id)) {
      rc = pthread_mutex_unlock(&kpm_ue_mutex);
      assert(rc == 0);
      return;
    }
  }

  if (store->len == store->cap) {
    const size_t new_cap = store->cap == 0 ? 4 : store->cap * 2;
    ue_id_e2sm_t *new_ues = realloc(store->ues, new_cap * sizeof(*new_ues));
    assert(new_ues != NULL && "Memory exhausted");
    store->ues = new_ues;
    store->cap = new_cap;
  }

  store->ues[store->len++] = cp_ue_id_e2sm(ue_id);
  rc = pthread_cond_broadcast(&kpm_ue_condition);
  assert(rc == 0);
  rc = pthread_mutex_unlock(&kpm_ue_mutex);
  assert(rc == 0);
}

void kpm_remember_ues(const global_e2_node_id_t *node_id, const kpm_ind_msg_t *msg) {
  assert(node_id != NULL);
  assert(msg != NULL);

  if (msg->type == FORMAT_2_INDICATION_MESSAGE) {
    for (size_t i = 0; i < msg->frm_2.meas_info_cond_ue_lst_len; ++i) {
      const meas_info_cond_ue_lst_t *info = &msg->frm_2.meas_info_cond_ue_lst[i];
      for (size_t j = 0; j < info->ue_id_matched_lst_len; ++j)
        remember_kpm_ue(node_id, &info->ue_id_matched_lst[j]);
    }
  } else if (msg->type == FORMAT_3_INDICATION_MESSAGE) {
    for (size_t i = 0; i < msg->frm_3.ue_meas_report_lst_len; ++i)
      remember_kpm_ue(node_id, &msg->frm_3.meas_report_per_ue[i].ue_meas_report_lst);
  }
}

static size_t wait_for_kpm_ues(const global_e2_node_id_t *node_id, size_t min_ues, uint32_t wait_ms) {
  struct timespec deadline = {0};
  int rc = clock_gettime(CLOCK_REALTIME, &deadline);
  assert(rc == 0);
  deadline.tv_sec += wait_ms / 1000;
  deadline.tv_nsec += (long)(wait_ms % 1000) * 1000000L;
  if (deadline.tv_nsec >= 1000000000L) {
    ++deadline.tv_sec;
    deadline.tv_nsec -= 1000000000L;
  }

  rc = pthread_mutex_lock(&kpm_ue_mutex);
  assert(rc == 0);
  kpm_node_ue_store_t *store = get_kpm_node_store(node_id, true);
  while (store->len < min_ues && rc == 0)
    rc = pthread_cond_timedwait(&kpm_ue_condition, &kpm_ue_mutex, &deadline);
  assert((rc == 0 || rc == ETIMEDOUT) && "Failed while waiting for UE discovery");
  const size_t len = store->len;
  rc = pthread_mutex_unlock(&kpm_ue_mutex);
  assert(rc == 0);
  return len;
}

static ue_id_e2sm_t *snapshot_kpm_ues(const global_e2_node_id_t *node_id, size_t *len) {
  int rc = pthread_mutex_lock(&kpm_ue_mutex);
  assert(rc == 0);
  kpm_node_ue_store_t *store = get_kpm_node_store(node_id, true);
  *len = store->len;
  ue_id_e2sm_t *snapshot = *len == 0 ? NULL : calloc(*len, sizeof(*snapshot));
  assert((*len == 0 || snapshot != NULL) && "Memory exhausted");
  for (size_t i = 0; i < *len; ++i)
    snapshot[i] = cp_ue_id_e2sm(&store->ues[i]);
  rc = pthread_mutex_unlock(&kpm_ue_mutex);
  assert(rc == 0);
  return snapshot;
}

static void free_kpm_ue_list(ue_id_e2sm_t *ues, size_t len) {
  for (size_t i = 0; i < len; ++i)
    free_ue_id_e2sm(&ues[i]);
  free(ues);
}

void kpm_reset_ue_registry(void) {
  int rc = pthread_mutex_lock(&kpm_ue_mutex);
  assert(rc == 0);
  for (size_t i = 0; i < kpm_node_ue_store_count; ++i) {
    kpm_node_ue_store_t *store = &kpm_node_ue_stores[i];
    free_global_e2_node_id(&store->node_id);
    free_kpm_ue_list(store->ues, store->len);
    *store = (kpm_node_ue_store_t){0};
  }
  kpm_node_ue_store_count = 0;
  rc = pthread_mutex_unlock(&kpm_ue_mutex);
  assert(rc == 0);
}

static const label_info_lst_t *format_2_measurement_label(const meas_info_cond_ue_lst_t *info) {
  static enum_value_e no_label_value = TRUE_ENUM_VALUE;
  static label_info_lst_t no_label = {.noLabel = &no_label_value};

  for (size_t i = 0; i < info->matching_cond_lst_len; ++i) {
    if (info->matching_cond_lst[i].cond_type == LABEL_INFO)
      return &info->matching_cond_lst[i].label_info_lst;
  }
  return &no_label;
}

static bool format_2_ue_seen(const kpm_ind_msg_format_2_t *msg, size_t info_idx, size_t ue_idx) {
  const ue_id_e2sm_t *candidate = &msg->meas_info_cond_ue_lst[info_idx].ue_id_matched_lst[ue_idx];
  for (size_t i = 0; i <= info_idx; ++i) {
    const meas_info_cond_ue_lst_t *info = &msg->meas_info_cond_ue_lst[i];
    const size_t limit = i == info_idx ? ue_idx : info->ue_id_matched_lst_len;
    for (size_t j = 0; j < limit; ++j) {
      if (same_kpm_ue_id(candidate, &info->ue_id_matched_lst[j]))
        return true;
    }
  }
  return false;
}

void kpm_visit_format_2(const kpm_ind_msg_format_2_t *msg, const kpm_format_2_visitor_t *visitor, void *context) {
  assert(msg != NULL);
  assert(visitor != NULL);

  for (size_t data_idx = 0; data_idx < msg->meas_data_lst_len; ++data_idx) {
    const meas_data_lst_t *data = &msg->meas_data_lst[data_idx];
    size_t expected_records = 0;
    for (size_t i = 0; i < msg->meas_info_cond_ue_lst_len; ++i)
      expected_records += msg->meas_info_cond_ue_lst[i].ue_id_matched_lst_len;

    for (size_t info_idx = 0; info_idx < msg->meas_info_cond_ue_lst_len; ++info_idx) {
      const meas_info_cond_ue_lst_t *candidate_info = &msg->meas_info_cond_ue_lst[info_idx];
      for (size_t ue_idx = 0; ue_idx < candidate_info->ue_id_matched_lst_len; ++ue_idx) {
        if (format_2_ue_seen(msg, info_idx, ue_idx))
          continue;

        const ue_id_e2sm_t *candidate = &candidate_info->ue_id_matched_lst[ue_idx];
        if (visitor->begin_ue != NULL)
          visitor->begin_ue(context, candidate);

        size_t record_idx = 0;
        for (size_t i = 0; i < msg->meas_info_cond_ue_lst_len; ++i) {
          const meas_info_cond_ue_lst_t *info = &msg->meas_info_cond_ue_lst[i];
          const label_info_lst_t *label = format_2_measurement_label(info);
          for (size_t j = 0; j < info->ue_id_matched_lst_len; ++j) {
            if (record_idx + j < data->meas_record_len && same_kpm_ue_id(candidate, &info->ue_id_matched_lst[j]) &&
                visitor->measurement != NULL)
              visitor->measurement(context, &info->meas_type, label, &data->meas_record_lst[record_idx + j]);
          }
          record_idx += info->ue_id_matched_lst_len;
        }

        const bool incomplete = data->incomplete_flag != NULL && *data->incomplete_flag == TRUE_ENUM_VALUE;
        if (visitor->end_ue != NULL)
          visitor->end_ue(context, incomplete);
      }
    }

    if (expected_records != data->meas_record_len)
      printf("[xApp] WARNING: KPM format 2 contained %zu records for %zu measurement/UE pairs.\n",
             data->meas_record_len, expected_records);
  }
}

static test_info_lst_t make_kpm_snssai_filter(test_cond_type_e type, test_cond_e cond, uint8_t sst, uint32_t sd) {
  test_info_lst_t filter = {0};
  filter.test_cond_type = type;
  // It can only be TRUE_TEST_COND_TYPE so it does not matter the type
  // but ugly ugly...
  filter.S_NSSAI = TRUE_TEST_COND_TYPE;
  filter.test_cond = ecalloc(1, sizeof(*filter.test_cond));
  *filter.test_cond = cond;
  filter.test_cond_value = ecalloc(1, sizeof(*filter.test_cond_value));
  filter.test_cond_value->type = OCTET_STRING_TEST_COND_VALUE;
  filter.test_cond_value->octet_string_value = ecalloc(1, sizeof(*filter.test_cond_value->octet_string_value));

  const size_t len = sd == 0xFFFFFF ? 1 : 4;
  byte_array_t *value = filter.test_cond_value->octet_string_value;
  value->len = len;
  value->buf = ecalloc(len, sizeof(*value->buf));
  value->buf[0] = sst;
  if (len == 4) {
    sd &= 0xFFFFFF;
    value->buf[1] = (uint8_t)(sd >> 16);
    value->buf[2] = (uint8_t)(sd >> 8);
    value->buf[3] = (uint8_t)sd;
  }
  return filter;
}

static kpm_act_def_format_1_t make_kpm_action_format_1(const ric_report_style_item_t *report_item, uint64_t period_ms) {
  kpm_act_def_format_1_t format = {0};
  // [1, 65535]
  format.meas_info_lst_len = report_item->meas_info_for_action_lst_len;
  format.meas_info_lst = ecalloc(format.meas_info_lst_len, sizeof(*format.meas_info_lst));
  for (size_t i = 0; i < format.meas_info_lst_len; ++i) {
    meas_info_format_1_lst_t *measurement = &format.meas_info_lst[i];
    // 8.3.9
    // Measurement Name
    measurement->meas_type.type = NAME_MEAS_TYPE;
    measurement->meas_type.name = copy_byte_array(report_item->meas_info_for_action_lst[i].name);
    // [1, 2147483647]
    // 8.3.11
    populate_label_info(measurement);
  }
  // 8.3.8 [0, 4294967295]
  format.gran_period_ms = period_ms;
  // 8.3.20 - OPTIONAL
  format.cell_global_id = NULL;
  // ad_frm_1.cell_global_id = calloc(1, sizeof(cell_global_id_t));
  // ad_frm_1.cell_global_id->type = NR_CGI_RAT_TYPE;
  // // Placeholder CGI just to be standards compliant in the Action Definition
  // ad_frm_1.cell_global_id->nr_cgi.plmn_id.mcc = 1;
  // ad_frm_1.cell_global_id->nr_cgi.plmn_id.mnc = 1;
  // ad_frm_1.cell_global_id->nr_cgi.plmn_id.mnc_digit_len = 2;
  // ad_frm_1.cell_global_id->nr_cgi.nr_cell_id = 12345;
  // act_def.frm_1.cell_global_id = calloc(1, sizeof(cell_global_id_t));
  // act_def.frm_1.cell_global_id->type = NR_CGI_RAT_TYPE;
  // // Placeholder CGI just to be standards compliant in the Action Definition
  // act_def.frm_1.cell_global_id->nr_cgi.plmn_id.mcc = 1;
  // act_def.frm_1.cell_global_id->nr_cgi.plmn_id.mnc = 1;
  // act_def.frm_1.cell_global_id->nr_cgi.plmn_id.mnc_digit_len = 2;
  // act_def.frm_1.cell_global_id->nr_cgi.nr_cell_id = 12345;
#if defined KPM_V2_03 || defined KPM_V3_00
  // [0, 65535]
  format.meas_bin_range_info_lst_len = 0;
  format.meas_bin_info_lst = NULL;
#endif
  return format;
}

static kpm_act_def_t make_kpm_action(const ric_report_style_item_t *report_item, kpm_subscription_config_t config,
                                     const ue_id_e2sm_t *ues, size_t ue_count) {
  switch (report_item->report_style_type) {
  case STYLE_1_RIC_SERVICE_REPORT:
    assert(report_item->act_def_format_type == FORMAT_1_ACTION_DEFINITION);
    return (kpm_act_def_t){.type = FORMAT_1_ACTION_DEFINITION,
                           .frm_1 = make_kpm_action_format_1(report_item, config.period_ms)};
  case STYLE_2_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_2_ACTION_DEFINITION);
    assert(ue_count >= 1);
    kpm_act_def_t action = {.type = FORMAT_2_ACTION_DEFINITION};
    action.frm_2.ue_id = cp_ue_id_e2sm(&ues[0]);
    action.frm_2.action_def_format_1 = make_kpm_action_format_1(report_item, config.period_ms);
    return action;
  }
  case STYLE_3_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_3_ACTION_DEFINITION);
    kpm_act_def_t action = {.type = FORMAT_3_ACTION_DEFINITION};
    action.frm_3.meas_info_lst_len = report_item->meas_info_for_action_lst_len;
    action.frm_3.meas_info_lst = ecalloc(action.frm_3.meas_info_lst_len, sizeof(*action.frm_3.meas_info_lst));
    for (size_t i = 0; i < action.frm_3.meas_info_lst_len; ++i) {
      meas_info_format_3_lst_t *measurement = &action.frm_3.meas_info_lst[i];
      measurement->meas_type.type = NAME_MEAS_TYPE;
      measurement->meas_type.name = copy_byte_array(report_item->meas_info_for_action_lst[i].name);
      measurement->matching_cond_lst_len = 1;
      measurement->matching_cond_lst = ecalloc(1, sizeof(*measurement->matching_cond_lst));
      measurement->matching_cond_lst[0].cond_type = LABEL_INFO;
      measurement->matching_cond_lst[0].label_info_lst.noLabel = ecalloc(1, sizeof(enum_value_e));
      *measurement->matching_cond_lst[0].label_info_lst.noLabel = TRUE_ENUM_VALUE;
    }
    action.frm_3.gran_period_ms = config.period_ms;
    return action;
  }
  case STYLE_4_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_4_ACTION_DEFINITION);
    kpm_act_def_t action = {.type = FORMAT_4_ACTION_DEFINITION};
    // Fill matching condition
    // [1, 32768]
    action.frm_4.matching_cond_lst_len = 1;
    action.frm_4.matching_cond_lst = ecalloc(1, sizeof(*action.frm_4.matching_cond_lst));
    // Filter connected UEs by S-NSSAI criteria
    test_cond_type_e const type = S_NSSAI_TEST_COND_TYPE; // CQI_TEST_COND_TYPE
    test_cond_e const condition = EQUAL_TEST_COND;        // GREATERTHAN_TEST_COND
    action.frm_4.matching_cond_lst[0].test_info_lst = make_kpm_snssai_filter(type, condition, config.sst, config.sd);
    // Fill Action Definition Format 1
    // 8.2.1.2.1
    action.frm_4.action_def_format_1 = make_kpm_action_format_1(report_item, config.period_ms);
    return action;
  }
  case STYLE_5_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_5_ACTION_DEFINITION);
    assert(ue_count >= 2);
    kpm_act_def_t action = {.type = FORMAT_5_ACTION_DEFINITION};
    action.frm_5.ue_id_lst_len = ue_count;
    action.frm_5.ue_id_lst = ecalloc(ue_count, sizeof(*action.frm_5.ue_id_lst));
    for (size_t i = 0; i < ue_count; ++i)
      action.frm_5.ue_id_lst[i] = cp_ue_id_e2sm(&ues[i]);
    action.frm_5.action_def_format_1 = make_kpm_action_format_1(report_item, config.period_ms);
    return action;
  }
  default:
    assert(false && "Unsupported KPM report style");
  }
  return (kpm_act_def_t){0};
}

static size_t required_kpm_ues(ric_service_report_e report_style) {
  if (report_style == STYLE_2_RIC_SERVICE_REPORT)
    return 1;
  if (report_style == STYLE_5_RIC_SERVICE_REPORT)
    return 2;
  return 0;
}

static kpm_sub_data_t make_kpm_subscription(const kpm_ran_function_def_t *ran_function,
                                            const ric_report_style_item_t *report_item,
                                            kpm_subscription_config_t config, const ue_id_e2sm_t *ues,
                                            size_t ue_count) {
  assert(ran_function->ric_event_trigger_style_list != NULL);
  assert(ran_function->ric_event_trigger_style_list[0].format_type == FORMAT_1_RIC_EVENT_TRIGGER);

  kpm_sub_data_t subscription = {0};
  // Generate Event Trigger
  subscription.ev_trg_def.type = FORMAT_1_RIC_EVENT_TRIGGER;
  subscription.ev_trg_def.kpm_ric_event_trigger_format_1.report_period_ms = config.period_ms;
  // Generate Action Definition
  // Multiple Action Definitions in one SUBSCRIPTION message is not supported in this project
  // Multiple REPORT Styles = Multiple Action Definition = Multiple SUBSCRIPTION messages
  subscription.sz_ad = 1;
  subscription.ad = ecalloc(1, sizeof(*subscription.ad));
  *subscription.ad = make_kpm_action(report_item, config, ues, ue_count);
  return subscription;
}

sm_ran_function_t *kpm_find_ran_function(e2_node_connected_xapp_t *node, uint32_t ran_function_id) {
  for (size_t i = 0; i < node->len_rf; ++i) {
    if (node->rf[i].id == ran_function_id) {
      assert(node->rf[i].defn.type == KPM_RAN_FUNC_DEF_E);
      return &node->rf[i];
    }
  }
  assert(false && "KPM RAN function not found");
  return NULL;
}

static void subscribe_kpm_style(e2_node_connected_xapp_t *node, sm_ran_function_t *ran_function,
                                ric_report_style_item_t *report_item, kpm_subscription_config_t config,
                                const ue_id_e2sm_t *ues, size_t ue_count, sm_cb callback, sm_ans_xapp_t *handle) {
  const size_t required_ues = required_kpm_ues(report_item->report_style_type);
  printf("[xApp] Subscribing to KPM report style %d", report_item->report_style_type + 1);
  if (required_ues != 0)
    printf(" with %zu discovered UE ID(s)",
           report_item->report_style_type == STYLE_2_RIC_SERVICE_REPORT ? 1 : ue_count);
  printf(".\n");

  // Generate KPM SUBSCRIPTION message
  kpm_sub_data_t subscription = make_kpm_subscription(&ran_function->defn.kpm, report_item, config, ues, ue_count);
  *handle = report_sm_xapp_api(&node->id, ran_function->id, &subscription, callback);
  assert(handle->success);
  free_kpm_sub_data(&subscription);
}

kpm_subscription_set_t kpm_subscribe_report_styles(const e2_node_arr_xapp_t *nodes, uint32_t ran_function_id,
                                                   kpm_subscription_config_t config, sm_cb callback) {
  assert(nodes != NULL);
  assert(callback != NULL);

  kpm_subscription_set_t subscriptions = {.node_count = nodes->len};
  subscriptions.handles = ecalloc(nodes->len, sizeof(*subscriptions.handles));
  subscriptions.handle_counts = ecalloc(nodes->len, sizeof(*subscriptions.handle_counts));

  for (size_t i = 0; i < nodes->len; ++i) {
    e2_node_connected_xapp_t *node = &nodes->n[i];
    sm_ran_function_t *ran_function = kpm_find_ran_function(node, ran_function_id);
    const size_t report_style_count = ran_function->defn.kpm.sz_ric_report_style_list;
    subscriptions.handle_counts[i] = report_style_count;
    subscriptions.handles[i] = ecalloc(report_style_count, sizeof(*subscriptions.handles[i]));

    // if REPORT Service is supported by E2 node, send SUBSCRIPTION
    // e.g. OAI CU-CP
    for (size_t j = 0; j < report_style_count; ++j) {
      ric_report_style_item_t *report_item = &ran_function->defn.kpm.ric_report_style_list[j];
      assert(report_item->report_style_type < END_RIC_SERVICE_REPORT);
      if (required_kpm_ues(report_item->report_style_type) == 0)
        subscribe_kpm_style(node, ran_function, report_item, config, NULL, 0, callback, &subscriptions.handles[i][j]);
    }
  }

  for (size_t i = 0; i < nodes->len; ++i) {
    e2_node_connected_xapp_t *node = &nodes->n[i];
    sm_ran_function_t *ran_function = kpm_find_ran_function(node, ran_function_id);
    const size_t report_style_count = ran_function->defn.kpm.sz_ric_report_style_list;
    size_t max_required_ues = 0;
    for (size_t j = 0; j < report_style_count; ++j) {
      const size_t required = required_kpm_ues(ran_function->defn.kpm.ric_report_style_list[j].report_style_type);
      if (required > max_required_ues)
        max_required_ues = required;
    }
    if (max_required_ues == 0)
      continue;

    const size_t discovered = wait_for_kpm_ues(&node->id, max_required_ues, config.ue_wait_ms);
    size_t ue_count = 0;
    ue_id_e2sm_t *ues = snapshot_kpm_ues(&node->id, &ue_count);
    printf("[xApp] Discovered %zu UE ID(s) for UE-specific KPM subscriptions%s.\n", ue_count,
           discovered < max_required_ues ? " before the discovery timeout" : "");

    for (size_t j = 0; j < report_style_count; ++j) {
      ric_report_style_item_t *report_item = &ran_function->defn.kpm.ric_report_style_list[j];
      const size_t required = required_kpm_ues(report_item->report_style_type);
      if (required == 0)
        continue;
      if (ue_count < required) {
        printf("[xApp] KPM report style %d deferred: it requires at least %zu discovered UE ID(s).\n",
               report_item->report_style_type + 1, required);
        continue;
      }
      subscribe_kpm_style(node, ran_function, report_item, config, ues, ue_count, callback,
                          &subscriptions.handles[i][j]);
    }
    free_kpm_ue_list(ues, ue_count);
  }

  return subscriptions;
}

void kpm_unsubscribe_report_styles(kpm_subscription_set_t *subscriptions) {
  if (subscriptions == NULL)
    return;
  for (size_t i = 0; i < subscriptions->node_count; ++i) {
    for (size_t j = 0; j < subscriptions->handle_counts[i]; ++j) {
      // Remove the handle previously returned
      if (subscriptions->handles[i][j].success)
        rm_report_sm_xapp_api(subscriptions->handles[i][j].u.handle);
    }
    free(subscriptions->handles[i]);
  }
  free(subscriptions->handles);
  free(subscriptions->handle_counts);
  *subscriptions = (kpm_subscription_set_t){0};
}
