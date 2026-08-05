#include "metrics_factory.h"
#include "../../../src/sm/rc_sm/rc_sm_id.h"
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
static pthread_mutex_t kpm_topology_mutex = PTHREAD_MUTEX_INITIALIZER;
static const e2_node_arr_xapp_t *kpm_topology;

typedef struct {
  global_e2_node_id_t du_node_id;
  cell_global_id_t cgi;
} kpm_cell_info_t;

typedef struct {
  sm_cb callback;
  global_e2_node_id_t du_node_id;
  uint64_t join_window_us;
  sm_ag_if_rd_t pending_du;
  sm_ag_if_rd_t pending_cell;
  bool pending_du_valid;
  bool pending_cell_valid;
} kpm_cell_callback_slot_t;

#define MAX_PENDING_KPM_UE_REPORTS 256

typedef struct {
  bool valid;
  sm_ag_if_rd_t report;
  global_e2_node_id_t node_id;
} kpm_ue_pending_report_t;

static pthread_mutex_t kpm_cell_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t kpm_cell_condition = PTHREAD_COND_INITIALIZER;
static pthread_mutex_t kpm_cell_callback_mutex = PTHREAD_MUTEX_INITIALIZER;
static kpm_cell_info_t kpm_cells[MAX_E2_NODES];
static size_t kpm_cell_count;
static kpm_cell_callback_slot_t kpm_cell_callback_slots[MAX_E2_NODES];
static size_t kpm_cell_callback_slot_count;
static _Thread_local const global_e2_node_id_t *kpm_callback_cell_node;
static pthread_mutex_t kpm_ue_join_mutex = PTHREAD_MUTEX_INITIALIZER;
static kpm_ue_pending_report_t kpm_ue_pending_reports[MAX_PENDING_KPM_UE_REPORTS];
static sm_cb kpm_ue_callback_target;
static uint64_t kpm_ue_join_window_us;
static _Thread_local const global_e2_node_id_t *kpm_callback_ue_du_node;
static _Thread_local const global_e2_node_id_t *kpm_callback_ue_cu_node;

static void clear_kpm_cells(void);

bool kpm_merge_format_1_indications(const kpm_ind_msg_format_1_t *du, const kpm_ind_msg_format_1_t *cell,
                                    kpm_ind_msg_format_1_t *merged) {
  assert(du != NULL);
  assert(cell != NULL);
  assert(merged != NULL);
  *merged = (kpm_ind_msg_format_1_t){0};

  if (du->meas_data_lst_len == 0 || du->meas_data_lst_len != cell->meas_data_lst_len ||
      du->meas_info_lst_len + cell->meas_info_lst_len >= 65536) {
    return false;
  }
  for (size_t i = 0; i < du->meas_data_lst_len; i++) {
    if (du->meas_data_lst[i].meas_record_len + cell->meas_data_lst[i].meas_record_len >= 65535) {
      return false;
    }
  }

  *merged = cp_kpm_ind_msg_frm_1(du);
  const size_t du_info_len = merged->meas_info_lst_len;
  merged->meas_info_lst_len += cell->meas_info_lst_len;
  merged->meas_info_lst = realloc(merged->meas_info_lst, merged->meas_info_lst_len * sizeof(*merged->meas_info_lst));
  assert(merged->meas_info_lst != NULL && "Memory exhausted");
  for (size_t i = 0; i < cell->meas_info_lst_len; i++) {
    merged->meas_info_lst[du_info_len + i] = cp_meas_info_format_1_lst(&cell->meas_info_lst[i]);
  }

  for (size_t i = 0; i < merged->meas_data_lst_len; i++) {
    meas_data_lst_t *dst = &merged->meas_data_lst[i];
    const meas_data_lst_t *src = &cell->meas_data_lst[i];
    const size_t du_record_len = dst->meas_record_len;
    dst->meas_record_len += src->meas_record_len;
    dst->meas_record_lst = realloc(dst->meas_record_lst, dst->meas_record_len * sizeof(*dst->meas_record_lst));
    assert(dst->meas_record_lst != NULL && "Memory exhausted");
    for (size_t j = 0; j < src->meas_record_len; j++) {
      dst->meas_record_lst[du_record_len + j] = cp_meas_record_lst(&src->meas_record_lst[j]);
    }
    if (src->incomplete_flag != NULL) {
      if (dst->incomplete_flag == NULL) {
        dst->incomplete_flag = ecalloc(1, sizeof(*dst->incomplete_flag));
      }
      if (*src->incomplete_flag == TRUE_ENUM_VALUE) {
        *dst->incomplete_flag = TRUE_ENUM_VALUE;
      }
    }
  }
  return true;
}

static bool kpm_ue_ids_match(const ue_id_e2sm_t *du, const ue_id_e2sm_t *cu) {
  if (du->type != GNB_DU_UE_ID_E2SM || cu->type != GNB_UE_ID_E2SM) {
    return false;
  }
  for (size_t i = 0; i < cu->gnb.gnb_cu_ue_f1ap_lst_len; i++) {
    if (du->gnb_du.gnb_cu_ue_f1ap == cu->gnb.gnb_cu_ue_f1ap_lst[i]) {
      return true;
    }
  }
  return false;
}

bool kpm_merge_ue_measurements(const meas_report_per_ue_t *du, const meas_report_per_ue_t *cu,
                               meas_report_per_ue_t *merged) {
  assert(du != NULL);
  assert(cu != NULL);
  assert(merged != NULL);
  *merged = (meas_report_per_ue_t){0};
  if (!kpm_ue_ids_match(&du->ue_meas_report_lst, &cu->ue_meas_report_lst)) {
    return false;
  }

  kpm_ind_msg_format_1_t measurements = {0};
  if (!kpm_merge_format_1_indications(&du->ind_msg_format_1, &cu->ind_msg_format_1, &measurements)) {
    return false;
  }
  merged->ue_meas_report_lst = cp_ue_id_e2sm(&du->ue_meas_report_lst);
  merged->ind_msg_format_1 = measurements;
  return true;
}

static bool is_kpm_format_1_report(const sm_ag_if_rd_t *rd) {
  return rd != NULL && rd->type == INDICATION_MSG_AGENT_IF_ANS_V0 && rd->ind.type == KPM_STATS_V3_0 &&
         rd->ind.kpm.ind.msg.type == FORMAT_1_INDICATION_MESSAGE;
}

static uint64_t kpm_format_1_collect_start_time(const sm_ag_if_rd_t *rd) {
  return rd->ind.kpm.ind.hdr.kpm_ric_ind_hdr_format_1.collectStartTime;
}

static void invoke_kpm_cell_callback(const kpm_cell_callback_slot_t *slot, const sm_ag_if_rd_t *rd,
                                     const global_e2_node_id_t *node_id) {
  const global_e2_node_id_t *previous = kpm_callback_cell_node;
  kpm_callback_cell_node = &slot->du_node_id;
  slot->callback(rd, node_id);
  kpm_callback_cell_node = previous;
}

static void move_pending_report(sm_ag_if_rd_t *reports, size_t *report_count, sm_ag_if_rd_t *pending,
                                bool *pending_valid) {
  assert(*report_count < 3);
  reports[(*report_count)++] = *pending;
  *pending = (sm_ag_if_rd_t){0};
  *pending_valid = false;
}

static void dispatch_kpm_cell_callback(size_t slot, const sm_ag_if_rd_t *rd, const global_e2_node_id_t *node_id) {
  assert(slot < kpm_cell_callback_slot_count);
  kpm_cell_callback_slot_t *callback_slot = &kpm_cell_callback_slots[slot];
  if (!is_kpm_format_1_report(rd) || node_id == NULL) {
    invoke_kpm_cell_callback(callback_slot, rd, node_id);
    return;
  }

  sm_ag_if_rd_t reports[3] = {0};
  size_t report_count = 0;
  int rc = pthread_mutex_lock(&kpm_cell_callback_mutex);
  assert(rc == 0);

  const bool is_du = node_id->type == ngran_gNB_DU;
  sm_ag_if_rd_t *pending = is_du ? &callback_slot->pending_du : &callback_slot->pending_cell;
  bool *pending_valid = is_du ? &callback_slot->pending_du_valid : &callback_slot->pending_cell_valid;
  if (*pending_valid) {
    move_pending_report(reports, &report_count, pending, pending_valid);
  }
  *pending = cp_sm_ag_if_rd(rd);
  *pending_valid = true;

  if (callback_slot->pending_du_valid && callback_slot->pending_cell_valid) {
    const uint64_t du_time = kpm_format_1_collect_start_time(&callback_slot->pending_du);
    const uint64_t cell_time = kpm_format_1_collect_start_time(&callback_slot->pending_cell);
    const uint64_t difference = du_time > cell_time ? du_time - cell_time : cell_time - du_time;
    if (difference <= callback_slot->join_window_us) {
      kpm_ind_msg_format_1_t merged = {0};
      const kpm_ind_msg_format_1_t *du_msg = &callback_slot->pending_du.ind.kpm.ind.msg.frm_1;
      const kpm_ind_msg_format_1_t *cell_msg = &callback_slot->pending_cell.ind.kpm.ind.msg.frm_1;
      if (kpm_merge_format_1_indications(du_msg, cell_msg, &merged)) {
        assert(report_count < 3);
        reports[report_count] = cp_sm_ag_if_rd(&callback_slot->pending_du);
        free_kpm_ind_msg_frm_1(&reports[report_count].ind.kpm.ind.msg.frm_1);
        reports[report_count].ind.kpm.ind.msg.frm_1 = merged;
        ++report_count;
        free_sm_ag_if_rd(&callback_slot->pending_du);
        free_sm_ag_if_rd(&callback_slot->pending_cell);
        callback_slot->pending_du = (sm_ag_if_rd_t){0};
        callback_slot->pending_cell = (sm_ag_if_rd_t){0};
        callback_slot->pending_du_valid = false;
        callback_slot->pending_cell_valid = false;
      } else {
        move_pending_report(reports, &report_count, &callback_slot->pending_du, &callback_slot->pending_du_valid);
        move_pending_report(reports, &report_count, &callback_slot->pending_cell, &callback_slot->pending_cell_valid);
      }
    } else if (du_time < cell_time) {
      move_pending_report(reports, &report_count, &callback_slot->pending_du, &callback_slot->pending_du_valid);
    } else {
      move_pending_report(reports, &report_count, &callback_slot->pending_cell, &callback_slot->pending_cell_valid);
    }
  }

  rc = pthread_mutex_unlock(&kpm_cell_callback_mutex);
  assert(rc == 0);
  for (size_t i = 0; i < report_count; i++) {
    invoke_kpm_cell_callback(callback_slot, &reports[i], &callback_slot->du_node_id);
    free_sm_ag_if_rd(&reports[i]);
  }
}

#define DEFINE_KPM_CELL_CALLBACK(index)                                                                                \
  static void kpm_cell_callback_##index(const sm_ag_if_rd_t *rd, const global_e2_node_id_t *node_id) {                 \
    dispatch_kpm_cell_callback(index, rd, node_id);                                                                    \
  }

DEFINE_KPM_CELL_CALLBACK(0)
DEFINE_KPM_CELL_CALLBACK(1)
DEFINE_KPM_CELL_CALLBACK(2)
DEFINE_KPM_CELL_CALLBACK(3)
DEFINE_KPM_CELL_CALLBACK(4)
DEFINE_KPM_CELL_CALLBACK(5)
DEFINE_KPM_CELL_CALLBACK(6)
DEFINE_KPM_CELL_CALLBACK(7)
DEFINE_KPM_CELL_CALLBACK(8)
DEFINE_KPM_CELL_CALLBACK(9)
DEFINE_KPM_CELL_CALLBACK(10)
DEFINE_KPM_CELL_CALLBACK(11)
DEFINE_KPM_CELL_CALLBACK(12)
DEFINE_KPM_CELL_CALLBACK(13)
DEFINE_KPM_CELL_CALLBACK(14)
DEFINE_KPM_CELL_CALLBACK(15)

static const sm_cb kpm_cell_callbacks[MAX_E2_NODES] = {
    kpm_cell_callback_0,  kpm_cell_callback_1,  kpm_cell_callback_2,  kpm_cell_callback_3,
    kpm_cell_callback_4,  kpm_cell_callback_5,  kpm_cell_callback_6,  kpm_cell_callback_7,
    kpm_cell_callback_8,  kpm_cell_callback_9,  kpm_cell_callback_10, kpm_cell_callback_11,
    kpm_cell_callback_12, kpm_cell_callback_13, kpm_cell_callback_14, kpm_cell_callback_15,
};

static sm_cb reserve_kpm_cell_callback(sm_cb callback, const global_e2_node_id_t *du_node_id, uint64_t join_window_us) {
  for (size_t i = 0; i < kpm_cell_callback_slot_count; i++) {
    if (kpm_cell_callback_slots[i].callback == callback &&
        eq_global_e2_node_id(&kpm_cell_callback_slots[i].du_node_id, du_node_id)) {
      kpm_cell_callback_slots[i].join_window_us = join_window_us;
      return kpm_cell_callbacks[i];
    }
  }
  assert(kpm_cell_callback_slot_count < MAX_E2_NODES);
  const size_t slot = kpm_cell_callback_slot_count++;
  kpm_cell_callback_slots[slot].callback = callback;
  kpm_cell_callback_slots[slot].du_node_id = cp_global_e2_node_id(du_node_id);
  kpm_cell_callback_slots[slot].join_window_us = join_window_us;
  return kpm_cell_callbacks[slot];
}

static bool is_kpm_format_3_report(const sm_ag_if_rd_t *rd) {
  return rd != NULL && rd->type == INDICATION_MSG_AGENT_IF_ANS_V0 && rd->ind.type == KPM_STATS_V3_0 &&
         rd->ind.kpm.ind.msg.type == FORMAT_3_INDICATION_MESSAGE;
}

static bool is_kpm_du_node(const global_e2_node_id_t *node_id) {
  return node_id != NULL && node_id->type == ngran_gNB_DU;
}

static bool is_kpm_cu_node(const global_e2_node_id_t *node_id) {
  return node_id != NULL && (node_id->type == ngran_gNB_CU || node_id->type == ngran_gNB_CUCP);
}

static bool same_kpm_gnb(const global_e2_node_id_t *lhs, const global_e2_node_id_t *rhs) {
  return eq_e2ap_plmn(&lhs->plmn, &rhs->plmn) && eq_e2ap_gnb_id(lhs->nb_id, rhs->nb_id);
}

static const meas_report_per_ue_t *single_kpm_ue_measurement(const sm_ag_if_rd_t *rd) {
  assert(is_kpm_format_3_report(rd));
  const kpm_ind_msg_format_3_t *msg = &rd->ind.kpm.ind.msg.frm_3;
  assert(msg->ue_meas_report_lst_len == 1);
  return &msg->meas_report_per_ue[0];
}

static sm_ag_if_rd_t copy_single_kpm_ue_report(const sm_ag_if_rd_t *rd, size_t index) {
  sm_ag_if_rd_t copy = cp_sm_ag_if_rd(rd);
  kpm_ind_msg_format_3_t *dst = &copy.ind.kpm.ind.msg.frm_3;
  const kpm_ind_msg_format_3_t *src = &rd->ind.kpm.ind.msg.frm_3;
  meas_report_per_ue_t item = {
      .ue_meas_report_lst = cp_ue_id_e2sm(&src->meas_report_per_ue[index].ue_meas_report_lst),
      .ind_msg_format_1 = cp_kpm_ind_msg_frm_1(&src->meas_report_per_ue[index].ind_msg_format_1),
  };
  free_kpm_ind_msg_frm_3(dst);
  dst->ue_meas_report_lst_len = 1;
  dst->meas_report_per_ue = ecalloc(1, sizeof(*dst->meas_report_per_ue));
  dst->meas_report_per_ue[0] = item;
  return copy;
}

static uint64_t kpm_report_time(const sm_ag_if_rd_t *rd) {
  return rd->ind.kpm.ind.hdr.kpm_ric_ind_hdr_format_1.collectStartTime;
}

static bool pending_kpm_ue_matches(const kpm_ue_pending_report_t *pending, const sm_ag_if_rd_t *report,
                                   const global_e2_node_id_t *node_id) {
  if (!pending->valid || !same_kpm_gnb(&pending->node_id, node_id) ||
      is_kpm_du_node(&pending->node_id) == is_kpm_du_node(node_id)) {
    return false;
  }
  const ue_id_e2sm_t *pending_id = &single_kpm_ue_measurement(&pending->report)->ue_meas_report_lst;
  const ue_id_e2sm_t *report_id = &single_kpm_ue_measurement(report)->ue_meas_report_lst;
  return is_kpm_du_node(&pending->node_id) ? kpm_ue_ids_match(pending_id, report_id)
                                           : kpm_ue_ids_match(report_id, pending_id);
}

static bool pending_kpm_ue_same_source(const kpm_ue_pending_report_t *pending, const sm_ag_if_rd_t *report,
                                       const global_e2_node_id_t *node_id) {
  if (!pending->valid || !eq_global_e2_node_id(&pending->node_id, node_id)) {
    return false;
  }
  return eq_ue_id_e2sm(&single_kpm_ue_measurement(&pending->report)->ue_meas_report_lst,
                       &single_kpm_ue_measurement(report)->ue_meas_report_lst);
}

static void free_pending_kpm_ue_report(kpm_ue_pending_report_t *pending) {
  if (pending->valid) {
    free_sm_ag_if_rd(&pending->report);
    free_global_e2_node_id(&pending->node_id);
  }
  *pending = (kpm_ue_pending_report_t){0};
}

static void invoke_kpm_ue_callback(const sm_ag_if_rd_t *rd, const global_e2_node_id_t *node_id,
                                   const global_e2_node_id_t *cu_node_id) {
  const global_e2_node_id_t *previous_du = kpm_callback_ue_du_node;
  const global_e2_node_id_t *previous_cu = kpm_callback_ue_cu_node;
  kpm_callback_ue_du_node = cu_node_id == NULL ? NULL : node_id;
  kpm_callback_ue_cu_node = cu_node_id;
  kpm_ue_callback_target(rd, node_id);
  kpm_callback_ue_du_node = previous_du;
  kpm_callback_ue_cu_node = previous_cu;
}

static bool merge_pending_kpm_ue_report(const kpm_ue_pending_report_t *pending, const sm_ag_if_rd_t *report,
                                        const global_e2_node_id_t *node_id, sm_ag_if_rd_t *merged,
                                        global_e2_node_id_t *du_node, global_e2_node_id_t *cu_node) {
  const bool pending_is_du = is_kpm_du_node(&pending->node_id);
  const sm_ag_if_rd_t *du_report = pending_is_du ? &pending->report : report;
  const sm_ag_if_rd_t *cu_report = pending_is_du ? report : &pending->report;
  const global_e2_node_id_t *du = pending_is_du ? &pending->node_id : node_id;
  const global_e2_node_id_t *cu = pending_is_du ? node_id : &pending->node_id;

  *merged = cp_sm_ag_if_rd(du_report);
  meas_report_per_ue_t *dst = &merged->ind.kpm.ind.msg.frm_3.meas_report_per_ue[0];
  meas_report_per_ue_t joined = {0};
  if (!kpm_merge_ue_measurements(single_kpm_ue_measurement(du_report), single_kpm_ue_measurement(cu_report), &joined)) {
    free_sm_ag_if_rd(merged);
    *merged = (sm_ag_if_rd_t){0};
    return false;
  }
  free_ue_id_e2sm(&dst->ue_meas_report_lst);
  free_kpm_ind_msg_frm_1(&dst->ind_msg_format_1);
  *dst = joined;
  *du_node = cp_global_e2_node_id(du);
  *cu_node = cp_global_e2_node_id(cu);
  return true;
}

static void dispatch_single_kpm_ue_report(sm_ag_if_rd_t *report, const global_e2_node_id_t *node_id) {
  bool report_valid = true;
  sm_ag_if_rd_t raw = {0};
  global_e2_node_id_t raw_node = {0};
  bool raw_valid = false;
  sm_ag_if_rd_t merged = {0};
  global_e2_node_id_t du_node = {0};
  global_e2_node_id_t cu_node = {0};
  bool merged_valid = false;

  int rc = pthread_mutex_lock(&kpm_ue_join_mutex);
  assert(rc == 0);
  size_t match = MAX_PENDING_KPM_UE_REPORTS;
  for (size_t i = 0; i < MAX_PENDING_KPM_UE_REPORTS; i++) {
    if (pending_kpm_ue_matches(&kpm_ue_pending_reports[i], report, node_id)) {
      match = i;
      break;
    }
  }

  if (match != MAX_PENDING_KPM_UE_REPORTS) {
    kpm_ue_pending_report_t *pending = &kpm_ue_pending_reports[match];
    const uint64_t pending_time = kpm_report_time(&pending->report);
    const uint64_t report_time = kpm_report_time(report);
    const uint64_t difference = pending_time > report_time ? pending_time - report_time : report_time - pending_time;
    if (difference <= kpm_ue_join_window_us) {
      merged_valid = merge_pending_kpm_ue_report(pending, report, node_id, &merged, &du_node, &cu_node);
      if (merged_valid) {
        free_pending_kpm_ue_report(pending);
        free_sm_ag_if_rd(report);
        *report = (sm_ag_if_rd_t){0};
        report_valid = false;
      } else {
        raw = pending->report;
        raw_node = pending->node_id;
        raw_valid = true;
        *pending = (kpm_ue_pending_report_t){0};
      }
    } else if (pending_time < report_time) {
      raw = pending->report;
      raw_node = pending->node_id;
      raw_valid = true;
      *pending = (kpm_ue_pending_report_t){0};
    } else {
      raw = *report;
      raw_node = cp_global_e2_node_id(node_id);
      raw_valid = true;
      *report = (sm_ag_if_rd_t){0};
      report_valid = false;
    }
  }

  if (!merged_valid && report_valid) {
    size_t slot = MAX_PENDING_KPM_UE_REPORTS;
    for (size_t i = 0; i < MAX_PENDING_KPM_UE_REPORTS; i++) {
      if (pending_kpm_ue_same_source(&kpm_ue_pending_reports[i], report, node_id)) {
        slot = i;
        if (!raw_valid) {
          raw = kpm_ue_pending_reports[i].report;
          raw_node = kpm_ue_pending_reports[i].node_id;
          raw_valid = true;
          kpm_ue_pending_reports[i] = (kpm_ue_pending_report_t){0};
        } else {
          free_pending_kpm_ue_report(&kpm_ue_pending_reports[i]);
        }
        break;
      }
      if (!kpm_ue_pending_reports[i].valid && slot == MAX_PENDING_KPM_UE_REPORTS) {
        slot = i;
      }
    }
    if (slot == MAX_PENDING_KPM_UE_REPORTS) {
      slot = 0;
      if (!raw_valid) {
        raw = kpm_ue_pending_reports[slot].report;
        raw_node = kpm_ue_pending_reports[slot].node_id;
        raw_valid = true;
        kpm_ue_pending_reports[slot] = (kpm_ue_pending_report_t){0};
      } else {
        free_pending_kpm_ue_report(&kpm_ue_pending_reports[slot]);
      }
    }
    kpm_ue_pending_reports[slot].valid = true;
    kpm_ue_pending_reports[slot].report = *report;
    kpm_ue_pending_reports[slot].node_id = cp_global_e2_node_id(node_id);
    *report = (sm_ag_if_rd_t){0};
    report_valid = false;
  }
  rc = pthread_mutex_unlock(&kpm_ue_join_mutex);
  assert(rc == 0);

  if (raw_valid) {
    invoke_kpm_ue_callback(&raw, &raw_node, NULL);
    free_sm_ag_if_rd(&raw);
    free_global_e2_node_id(&raw_node);
  }
  if (merged_valid) {
    invoke_kpm_ue_callback(&merged, &du_node, &cu_node);
    free_sm_ag_if_rd(&merged);
    free_global_e2_node_id(&du_node);
    free_global_e2_node_id(&cu_node);
  }
}

static void kpm_ue_callback(const sm_ag_if_rd_t *rd, const global_e2_node_id_t *node_id) {
  if (!is_kpm_format_3_report(rd) || (!is_kpm_du_node(node_id) && !is_kpm_cu_node(node_id))) {
    kpm_ue_callback_target(rd, node_id);
    return;
  }
  kpm_remember_ues(node_id, &rd->ind.kpm.ind.msg);
  const kpm_ind_msg_format_3_t *msg = &rd->ind.kpm.ind.msg.frm_3;
  for (size_t i = 0; i < msg->ue_meas_report_lst_len; i++) {
    sm_ag_if_rd_t report = copy_single_kpm_ue_report(rd, i);
    dispatch_single_kpm_ue_report(&report, node_id);
  }
}

static sm_cb reserve_kpm_ue_callback(sm_cb callback, uint64_t join_window_us) {
  assert(kpm_ue_callback_target == NULL || kpm_ue_callback_target == callback);
  kpm_ue_callback_target = callback;
  kpm_ue_join_window_us = join_window_us;
  return kpm_ue_callback;
}

static void format_single_e2_node_id(char *dst, size_t dst_len, const global_e2_node_id_t *node_id) {
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

void format_e2_node_id(char *dst, size_t dst_len, const global_e2_node_id_t *node_id) {
  if (kpm_callback_ue_du_node != NULL && kpm_callback_ue_cu_node != NULL) {
    char du[128];
    char cu[128];
    format_single_e2_node_id(du, sizeof(du), kpm_callback_ue_du_node);
    format_single_e2_node_id(cu, sizeof(cu), kpm_callback_ue_cu_node);
    snprintf(dst, dst_len, "%s+%s", du, cu);
    return;
  }
  format_single_e2_node_id(dst, dst_len, node_id);
}

void kpm_set_e2_node_topology(const e2_node_arr_xapp_t *nodes) {
  assert(nodes != NULL);

  int rc = pthread_mutex_lock(&kpm_topology_mutex);
  assert(rc == 0);
  kpm_topology = nodes;
  rc = pthread_mutex_unlock(&kpm_topology_mutex);
  assert(rc == 0);
}

void format_kpm_cell_node_id(char *dst, size_t dst_len, const global_e2_node_id_t *node_id) {
  assert(dst != NULL);
  assert(dst_len > 0);

  if (kpm_callback_cell_node != NULL) {
    format_e2_node_id(dst, dst_len, kpm_callback_cell_node);
    return;
  }

  if (node_id == NULL || (node_id->type != ngran_gNB_CU && node_id->type != ngran_gNB_CUCP)) {
    format_e2_node_id(dst, dst_len, node_id);
    return;
  }

  int rc = pthread_mutex_lock(&kpm_topology_mutex);
  assert(rc == 0);
  const global_e2_node_id_t *matched_du = NULL;
  size_t match_count = 0;
  const size_t node_count = kpm_topology == NULL ? 0 : kpm_topology->len;
  for (size_t i = 0; i < node_count; i++) {
    const global_e2_node_id_t *candidate = &kpm_topology->n[i].id;
    if (candidate->type == ngran_gNB_DU && eq_e2ap_plmn(&candidate->plmn, &node_id->plmn) &&
        eq_e2ap_gnb_id(candidate->nb_id, node_id->nb_id)) {
      matched_du = candidate;
      ++match_count;
    }
  }
  format_e2_node_id(dst, dst_len, match_count == 1 ? matched_du : node_id);
  rc = pthread_mutex_unlock(&kpm_topology_mutex);
  assert(rc == 0);
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
  if (!out_metrics) {
    return false;
  }
  out_metrics->mean = NAN;
  out_metrics->min = NAN;
  out_metrics->q1 = NAN;     // Removal candidate
  out_metrics->median = NAN; // Removal candidate
  out_metrics->q3 = NAN;     // Removal candidate
  out_metrics->max = NAN;
  out_metrics->count = 0;

  if (!node_id || node_id[0] == '\0' || !current_dist || limit == 0 || limit > 128) {
    return false;
  }

  e2_node_dist_state_t *state = get_dist_state(node_id);
  if (!state) {
    return false;
  }

  uint32_t diff_dist[128] = {0};
  uint32_t total_count = 0;
  uint32_t total_current = 0;

  for (size_t i = 0; i < limit; i++) {
    total_current += current_dist[i];
  }

  if (!state->ss_rsrp_initialized) {
    memcpy(state->last_ss_rsrp_dist, current_dist, limit * sizeof(current_dist[0]));
    state->ss_rsrp_initialized = true;
    return false;
  }

  // Per-UE metrics don't have RSRP; return early
  if (total_current == 0) {
    return false;
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
    return false;
  }

  double sum = 0;
  int min_val = 9999, max_val = -9999;
  for (size_t i = 0; i < limit; i++) {
    if (diff_dist[i] > 0) {
      // 38.133, Table 10.1.6.1-1: SS-RSRP and CSI-RSRP measurement report mapping
      int dbm_val = -(156 + 1) + i;
      double linear_val = pow(10.0, dbm_val / 10.0);
      sum += linear_val * diff_dist[i];
      if (dbm_val < min_val) {
        min_val = dbm_val;
      }
      if (dbm_val > max_val) {
        max_val = dbm_val;
      }
    }
  }

  out_metrics->mean = 10.0 * log10(sum / total_count);
  out_metrics->min = (double)min_val;
  out_metrics->q1 = get_percentile_val(diff_dist, (total_count - 1) / 4);               // Removal candidate
  out_metrics->median = get_percentile_val(diff_dist, (total_count - 1) / 2);           // Removal candidate
  out_metrics->q3 = get_percentile_val(diff_dist, ((uint64_t)3 * total_count - 1) / 4); // Removal candidate
  out_metrics->max = (double)max_val;
  out_metrics->count = total_count;

  return true;
}

bool compute_sinr_metrics(const char *node_id, const uint32_t *current_dist, size_t limit,
                          dist_metrics_t *out_metrics) {
  if (!out_metrics) {
    return false;
  }
  out_metrics->mean = NAN;
  out_metrics->min = NAN;
  out_metrics->q1 = NAN;     // Removal candidate
  out_metrics->median = NAN; // Removal candidate
  out_metrics->q3 = NAN;     // Removal candidate
  out_metrics->max = NAN;
  out_metrics->count = 0;

  if (!node_id || node_id[0] == '\0' || !current_dist || limit == 0 || limit > 128) {
    return false;
  }

  e2_node_dist_state_t *state = get_dist_state(node_id);
  if (!state) {
    return false;
  }

  uint32_t diff_dist[128] = {0};
  uint32_t total_count = 0;
  uint32_t total_current = 0;

  for (size_t i = 0; i < limit; i++) {
    total_current += current_dist[i];
  }

  if (!state->ss_sinr_initialized) {
    memcpy(state->last_ss_sinr_dist, current_dist, limit * sizeof(current_dist[0]));
    state->ss_sinr_initialized = true;
    return false;
  }

  if (total_current == 0) {
    return false;
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
    return false;
  }

  double sum = 0;
  double min_val = 9999.0, max_val = -9999.0;
  for (size_t i = 0; i < limit; i++) {
    if (diff_dist[i] > 0) {
      double db_val = ss_sinr_level_representative_db(i);
      double linear_val = pow(10.0, db_val / 10.0);
      sum += linear_val * diff_dist[i];
      if (db_val < min_val) {
        min_val = db_val;
      }
      if (db_val > max_val) {
        max_val = db_val;
      }
    }
  }

  out_metrics->mean = 10.0 * log10(sum / total_count);
  out_metrics->min = min_val;
  out_metrics->q1 = get_sinr_percentile_val(diff_dist, (total_count - 1) / 4);               // Removal candidate
  out_metrics->median = get_sinr_percentile_val(diff_dist, (total_count - 1) / 2);           // Removal candidate
  out_metrics->q3 = get_sinr_percentile_val(diff_dist, ((uint64_t)3 * total_count - 1) / 4); // Removal candidate
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
  if (strcmp(metric_name, "L1M.SS-RSRP") == 0) {
    return describe_distribution_metrics("RSRP", "dBm");
  }
  if (strcmp(metric_name, "MR.NRScSSSINR") == 0) {
    return describe_distribution_metrics("SINR", "dB");
  }
  return (factory_metrics_array_t){0};
}

static bool read_distribution(const label_info_lst_t *labels, size_t label_count, const meas_record_lst_t *records,
                              size_t record_start, uint32_t distribution[128]) {
  if (!labels || !records || label_count != 128) {
    return false;
  }

  bool seen[128] = {0};
  for (size_t i = 0; i < label_count; i++) {
    if (!labels[i].distBinX || *labels[i].distBinX >= 128 || seen[*labels[i].distBinX]) {
      return false;
    }

    const meas_record_lst_t record = records[record_start + i];
    uint32_t count = 0;
    if (record.value == 0) {
      if (record.int_val > UINT32_MAX) {
        return false;
      }
      count = (uint32_t)record.int_val;
    } else if (record.value == 1) {
      if (!isfinite(record.real_val) || record.real_val < 0.0 || record.real_val > UINT32_MAX ||
          trunc(record.real_val) != record.real_val) {
        return false;
      }
      count = (uint32_t)record.real_val;
    } else {
      return false;
    }

    distribution[*labels[i].distBinX] = count;
    seen[*labels[i].distBinX] = true;
  }
  return true;
}

factory_metrics_array_t process_metric_factory(const char *node_id, const char *metric_name,
                                               const label_info_lst_t *label_info_lst, size_t label_info_lst_len,
                                               const meas_record_lst_t *meas_record_lst, size_t rec_idx_start) {
  factory_metrics_array_t ret = {0};

  // Derive RSRP.Mean, RSRP.Minimum, RSRP.Maximum, and RSRP.Count from L1M.SS-RSRP
  if (strcmp(metric_name, "L1M.SS-RSRP") == 0) {
    uint32_t current_dist[128] = {0};
    if (!read_distribution(label_info_lst, label_info_lst_len, meas_record_lst, rec_idx_start, current_dist)) {
      return ret;
    }

    dist_metrics_t metrics;
    if (compute_rsrp_metrics(node_id, current_dist, 128, &metrics)) {
      ret = describe_metric_factory(metric_name);
      assert(ret.count == 7);
      ret.metrics[0].real_val = metrics.mean;
      ret.metrics[1].real_val = metrics.min;
      ret.metrics[2].real_val = metrics.q1;     // Removal candidate
      ret.metrics[3].real_val = metrics.median; // Removal candidate
      ret.metrics[4].real_val = metrics.q3;     // Removal candidate
      ret.metrics[5].real_val = metrics.max;
      ret.metrics[6].int_val = metrics.count;
    }
  }

  // Derive SINR metrics
  if (strcmp(metric_name, "MR.NRScSSSINR") == 0) {
    uint32_t current_dist[128] = {0};
    if (!read_distribution(label_info_lst, label_info_lst_len, meas_record_lst, rec_idx_start, current_dist)) {
      return ret;
    }

    dist_metrics_t metrics;
    if (compute_sinr_metrics(node_id, current_dist, 128, &metrics)) {
      ret = describe_metric_factory(metric_name);
      assert(ret.count == 7);
      ret.metrics[0].real_val = metrics.mean;
      ret.metrics[1].real_val = metrics.min;
      ret.metrics[2].real_val = metrics.q1;     // Removal candidate
      ret.metrics[3].real_val = metrics.median; // Removal candidate
      ret.metrics[4].real_val = metrics.q3;     // Removal candidate
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
      if (has_z) {
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[[[");
      } else if (has_y) {
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[[");
      } else {
        n = snprintf(arr_str + arr_len, max_len - arr_len, "[");
      }
    } else {
      if (has_z && cur_x != last_x) {
        n = snprintf(arr_str + arr_len, max_len - arr_len, "]], [[");
      } else if (has_z && cur_y != last_y) {
        n = snprintf(arr_str + arr_len, max_len - arr_len, "], [");
      } else if (has_y && cur_x != last_x) {
        n = snprintf(arr_str + arr_len, max_len - arr_len, "], [");
      } else {
        n = snprintf(arr_str + arr_len, max_len - arr_len, ", ");
      }
    }
    if (n > 0) {
      arr_len += ((size_t)n < max_len - arr_len) ? (size_t)n : max_len - arr_len - 1;
    }

    if (record_item.value == 0) {
      n = snprintf(arr_str + arr_len, max_len - arr_len, "%d", record_item.int_val);
    } else if (record_item.value == 1) {
      n = snprintf(arr_str + arr_len, max_len - arr_len, "%.2f", record_item.real_val);
    } else {
      n = snprintf(arr_str + arr_len, max_len - arr_len, "null");
    }

    if (n > 0) {
      arr_len += ((size_t)n < max_len - arr_len) ? (size_t)n : max_len - arr_len - 1;
    }

    last_x = cur_x;
    last_y = cur_y;
  }

  if (label_info_lst_len > 0) {
    int n = 0;
    if (has_z) {
      n = snprintf(arr_str + arr_len, max_len - arr_len, "]]]");
    } else if (has_y) {
      n = snprintf(arr_str + arr_len, max_len - arr_len, "]]");
    } else {
      n = snprintf(arr_str + arr_len, max_len - arr_len, "]");
    }
    if (n > 0) {
      arr_len += ((size_t)n < max_len - arr_len) ? (size_t)n : max_len - arr_len - 1;
    }
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

  if (lhs->type != rhs->type) {
    return false;
  }

  if (lhs->type == GNB_DU_UE_ID_E2SM) {
    if (lhs->gnb_du.gnb_cu_ue_f1ap != rhs->gnb_du.gnb_cu_ue_f1ap) {
      return false;
    }
    if (lhs->gnb_du.ran_ue_id == NULL || rhs->gnb_du.ran_ue_id == NULL) {
      return lhs->gnb_du.ran_ue_id == rhs->gnb_du.ran_ue_id;
    }
    return *lhs->gnb_du.ran_ue_id == *rhs->gnb_du.ran_ue_id;
  }

  return eq_ue_id_e2sm(lhs, rhs);
}

static kpm_node_ue_store_t *get_kpm_node_store(const global_e2_node_id_t *node_id, bool create) {
  assert(node_id != NULL);

  for (size_t i = 0; i < kpm_node_ue_store_count; i++) {
    if (eq_global_e2_node_id(&kpm_node_ue_stores[i].node_id, node_id)) {
      return &kpm_node_ue_stores[i];
    }
  }

  if (!create) {
    return NULL;
  }

  assert(kpm_node_ue_store_count < MAX_E2_NODES);
  kpm_node_ue_store_t *store = &kpm_node_ue_stores[kpm_node_ue_store_count++];
  store->node_id = cp_global_e2_node_id(node_id);
  return store;
}

static void remember_kpm_ue(const global_e2_node_id_t *node_id, const ue_id_e2sm_t *ue_id) {
  int rc = pthread_mutex_lock(&kpm_ue_mutex);
  assert(rc == 0);

  kpm_node_ue_store_t *store = get_kpm_node_store(node_id, true);
  for (size_t i = 0; i < store->len; i++) {
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
    for (size_t i = 0; i < msg->frm_2.meas_info_cond_ue_lst_len; i++) {
      const meas_info_cond_ue_lst_t *info = &msg->frm_2.meas_info_cond_ue_lst[i];
      for (size_t j = 0; j < info->ue_id_matched_lst_len; j++) {
        remember_kpm_ue(node_id, &info->ue_id_matched_lst[j]);
      }
    }
  } else if (msg->type == FORMAT_3_INDICATION_MESSAGE) {
    for (size_t i = 0; i < msg->frm_3.ue_meas_report_lst_len; i++) {
      remember_kpm_ue(node_id, &msg->frm_3.meas_report_per_ue[i].ue_meas_report_lst);
    }
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
  while (store->len < min_ues && rc == 0) {
    rc = pthread_cond_timedwait(&kpm_ue_condition, &kpm_ue_mutex, &deadline);
  }
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
  for (size_t i = 0; i < *len; i++) {
    snapshot[i] = cp_ue_id_e2sm(&store->ues[i]);
  }
  rc = pthread_mutex_unlock(&kpm_ue_mutex);
  assert(rc == 0);
  return snapshot;
}

static void free_kpm_ue_list(ue_id_e2sm_t *ues, size_t len) {
  for (size_t i = 0; i < len; i++) {
    free_ue_id_e2sm(&ues[i]);
  }
  free(ues);
}

void kpm_reset_ue_registry(void) {
  int rc = pthread_mutex_lock(&kpm_ue_mutex);
  assert(rc == 0);
  for (size_t i = 0; i < kpm_node_ue_store_count; i++) {
    kpm_node_ue_store_t *store = &kpm_node_ue_stores[i];
    free_global_e2_node_id(&store->node_id);
    free_kpm_ue_list(store->ues, store->len);
    *store = (kpm_node_ue_store_t){0};
  }
  kpm_node_ue_store_count = 0;
  rc = pthread_mutex_unlock(&kpm_ue_mutex);
  assert(rc == 0);

  clear_kpm_cells();
  rc = pthread_mutex_lock(&kpm_cell_callback_mutex);
  assert(rc == 0);
  for (size_t i = 0; i < kpm_cell_callback_slot_count; i++) {
    if (kpm_cell_callback_slots[i].pending_du_valid) {
      free_sm_ag_if_rd(&kpm_cell_callback_slots[i].pending_du);
    }
    if (kpm_cell_callback_slots[i].pending_cell_valid) {
      free_sm_ag_if_rd(&kpm_cell_callback_slots[i].pending_cell);
    }
    free_global_e2_node_id(&kpm_cell_callback_slots[i].du_node_id);
    kpm_cell_callback_slots[i] = (kpm_cell_callback_slot_t){0};
  }
  kpm_cell_callback_slot_count = 0;
  rc = pthread_mutex_unlock(&kpm_cell_callback_mutex);
  assert(rc == 0);

  rc = pthread_mutex_lock(&kpm_ue_join_mutex);
  assert(rc == 0);
  for (size_t i = 0; i < MAX_PENDING_KPM_UE_REPORTS; i++) {
    free_pending_kpm_ue_report(&kpm_ue_pending_reports[i]);
  }
  kpm_ue_callback_target = NULL;
  kpm_ue_join_window_us = 0;
  rc = pthread_mutex_unlock(&kpm_ue_join_mutex);
  assert(rc == 0);

  rc = pthread_mutex_lock(&kpm_topology_mutex);
  assert(rc == 0);
  kpm_topology = NULL;
  rc = pthread_mutex_unlock(&kpm_topology_mutex);
  assert(rc == 0);
}

static const label_info_lst_t *format_2_measurement_label(const meas_info_cond_ue_lst_t *info) {
  static enum_value_e no_label_value = TRUE_ENUM_VALUE;
  static label_info_lst_t no_label = {.noLabel = &no_label_value};

  for (size_t i = 0; i < info->matching_cond_lst_len; i++) {
    if (info->matching_cond_lst[i].cond_type == LABEL_INFO) {
      return &info->matching_cond_lst[i].label_info_lst;
    }
  }
  return &no_label;
}

static bool format_2_ue_seen(const kpm_ind_msg_format_2_t *msg, size_t info_idx, size_t ue_idx) {
  const ue_id_e2sm_t *candidate = &msg->meas_info_cond_ue_lst[info_idx].ue_id_matched_lst[ue_idx];
  for (size_t i = 0; i <= info_idx; i++) {
    const meas_info_cond_ue_lst_t *info = &msg->meas_info_cond_ue_lst[i];
    const size_t limit = i == info_idx ? ue_idx : info->ue_id_matched_lst_len;
    for (size_t j = 0; j < limit; j++) {
      if (same_kpm_ue_id(candidate, &info->ue_id_matched_lst[j])) {
        return true;
      }
    }
  }
  return false;
}

void kpm_visit_format_2(const kpm_ind_msg_format_2_t *msg, const kpm_format_2_visitor_t *visitor, void *context) {
  assert(msg != NULL);
  assert(visitor != NULL);

  for (size_t data_idx = 0; data_idx < msg->meas_data_lst_len; data_idx++) {
    const meas_data_lst_t *data = &msg->meas_data_lst[data_idx];
    size_t expected_records = 0;
    for (size_t i = 0; i < msg->meas_info_cond_ue_lst_len; i++) {
      expected_records += msg->meas_info_cond_ue_lst[i].ue_id_matched_lst_len;
    }

    for (size_t info_idx = 0; info_idx < msg->meas_info_cond_ue_lst_len; info_idx++) {
      const meas_info_cond_ue_lst_t *candidate_info = &msg->meas_info_cond_ue_lst[info_idx];
      for (size_t ue_idx = 0; ue_idx < candidate_info->ue_id_matched_lst_len; ue_idx++) {
        if (format_2_ue_seen(msg, info_idx, ue_idx)) {
          continue;
        }

        const ue_id_e2sm_t *candidate = &candidate_info->ue_id_matched_lst[ue_idx];
        if (visitor->begin_ue != NULL) {
          visitor->begin_ue(context, candidate);
        }

        size_t record_idx = 0;
        for (size_t i = 0; i < msg->meas_info_cond_ue_lst_len; i++) {
          const meas_info_cond_ue_lst_t *info = &msg->meas_info_cond_ue_lst[i];
          const label_info_lst_t *label = format_2_measurement_label(info);
          for (size_t j = 0; j < info->ue_id_matched_lst_len; j++) {
            if (record_idx + j < data->meas_record_len && same_kpm_ue_id(candidate, &info->ue_id_matched_lst[j]) &&
                visitor->measurement != NULL) {
              visitor->measurement(context, &info->meas_type, label, &data->meas_record_lst[record_idx + j]);
            }
          }
          record_idx += info->ue_id_matched_lst_len;
        }

        const bool incomplete = data->incomplete_flag != NULL && *data->incomplete_flag == TRUE_ENUM_VALUE;
        if (visitor->end_ue != NULL) {
          visitor->end_ue(context, incomplete);
        }
      }
    }

    if (expected_records != data->meas_record_len) {
      printf("[xApp] WARNING: KPM format 2 contained %zu records for %zu measurement/UE pairs.\n",
             data->meas_record_len, expected_records);
    }
  }
}

static sm_ran_function_t *find_ran_function(e2_node_connected_xapp_t *node, uint32_t ran_function_id,
                                            ran_func_def_e type) {
  for (size_t i = 0; i < node->len_rf; i++) {
    if (node->rf[i].id == ran_function_id && node->rf[i].defn.type == type) {
      return &node->rf[i];
    }
  }
  return NULL;
}

static const seq_report_sty_t *find_rc_common_information_style(e2_node_connected_xapp_t *node) {
  sm_ran_function_t *ran_function = find_ran_function(node, SM_RC_ID, RC_RAN_FUNC_DEF_E);
  if (ran_function == NULL || ran_function->defn.rc.report == NULL) {
    return NULL;
  }

  const ran_func_def_report_t *report = ran_function->defn.rc.report;
  for (size_t i = 0; i < report->sz_seq_report_sty; i++) {
    const seq_report_sty_t *style = &report->seq_report_sty[i];
    if (style->report_type == 5 && style->ev_trig_type == FORMAT_5_E2SM_RC_EV_TRIGGER_FORMAT &&
        style->act_frmt_type == FORMAT_1_E2SM_RC_ACT_DEF && style->ind_msg_type == FORMAT_4_E2SM_RC_IND_MSG) {
      return style;
    }
  }
  return NULL;
}

static rc_sub_data_t make_rc_cell_discovery_subscription(const seq_report_sty_t *style) {
  assert(style != NULL);
  rc_sub_data_t subscription = {0};
  subscription.et.format = FORMAT_5_E2SM_RC_EV_TRIGGER_FORMAT;
  subscription.et.frmt_5.on_demand = TRUE_ON_DEMAND_FRMT_5;
  subscription.sz_ad = 1;
  subscription.ad = ecalloc(1, sizeof(*subscription.ad));
  subscription.ad[0].ric_style_type = 5;
  subscription.ad[0].format = FORMAT_1_E2SM_RC_ACT_DEF;
  subscription.ad[0].frmt_1.sz_param_report_def = 1;
  subscription.ad[0].frmt_1.param_report_def = ecalloc(1, sizeof(*subscription.ad[0].frmt_1.param_report_def));
  subscription.ad[0].frmt_1.param_report_def[0].ran_param_id = E2SM_RC_RS5_CELL_CONTEXT_INFORMATION;

  bool advertised = false;
  for (size_t i = 0; i < style->sz_seq_ran_param; i++) {
    advertised |= style->ran_param[i].id == E2SM_RC_RS5_CELL_CONTEXT_INFORMATION;
  }
  assert(advertised && "RC Common Information must advertise Cell Context Information");
  return subscription;
}

static void remember_kpm_cell(const global_e2_node_id_t *du_node_id, const cell_global_id_t *cgi) {
  int rc = pthread_mutex_lock(&kpm_cell_mutex);
  assert(rc == 0);

  for (size_t i = 0; i < kpm_cell_count; i++) {
    if (eq_global_e2_node_id(&kpm_cells[i].du_node_id, du_node_id) && eq_cell_global_id(&kpm_cells[i].cgi, cgi)) {
      rc = pthread_mutex_unlock(&kpm_cell_mutex);
      assert(rc == 0);
      return;
    }
  }

  assert(kpm_cell_count < MAX_E2_NODES);
  kpm_cells[kpm_cell_count].du_node_id = cp_global_e2_node_id(du_node_id);
  kpm_cells[kpm_cell_count].cgi = cp_cell_global_id(cgi);
  ++kpm_cell_count;
  rc = pthread_cond_broadcast(&kpm_cell_condition);
  assert(rc == 0);
  rc = pthread_mutex_unlock(&kpm_cell_mutex);
  assert(rc == 0);
}

static void sm_cb_rc_cell_discovery(const sm_ag_if_rd_t *rd, const global_e2_node_id_t *node_id) {
  if (rd == NULL || node_id == NULL || node_id->type != ngran_gNB_DU || rd->type != INDICATION_MSG_AGENT_IF_ANS_V0 ||
      rd->ind.type != RAN_CTRL_STATS_V1_03) {
    return;
  }

  const rc_ind_data_t *ind = &rd->ind.rc.ind;
  if (ind->msg.format != FORMAT_4_E2SM_RC_IND_MSG) {
    return;
  }
  for (size_t i = 0; i < ind->msg.frmt_4.sz_seq_cell_info_2; i++) {
    const cell_global_id_t *cgi = &ind->msg.frmt_4.seq_cell_info_2[i].cell_global_id;
    if (cgi->type == NR_CGI_RAT_TYPE) {
      remember_kpm_cell(node_id, cgi);
    }
  }
}

static size_t discovered_du_count(const global_e2_node_id_t *const *expected, size_t expected_count) {
  size_t count = 0;
  for (size_t i = 0; i < expected_count; i++) {
    for (size_t j = 0; j < kpm_cell_count; j++) {
      if (eq_global_e2_node_id(expected[i], &kpm_cells[j].du_node_id)) {
        ++count;
        break;
      }
    }
  }
  return count;
}

static void clear_kpm_cells(void) {
  int rc = pthread_mutex_lock(&kpm_cell_mutex);
  assert(rc == 0);
  for (size_t i = 0; i < kpm_cell_count; i++) {
    free_global_e2_node_id(&kpm_cells[i].du_node_id);
    free_cell_global_id(&kpm_cells[i].cgi);
    kpm_cells[i] = (kpm_cell_info_t){0};
  }
  kpm_cell_count = 0;
  rc = pthread_mutex_unlock(&kpm_cell_mutex);
  assert(rc == 0);
}

static void discover_kpm_cells(const e2_node_arr_xapp_t *nodes, uint32_t wait_ms) {
  clear_kpm_cells();
  sm_ans_xapp_t handles[MAX_E2_NODES] = {0};
  const global_e2_node_id_t *expected[MAX_E2_NODES] = {0};
  size_t handle_count = 0;
  size_t expected_count = 0;

  for (size_t i = 0; i < nodes->len; i++) {
    e2_node_connected_xapp_t *node = &nodes->n[i];
    if (node->id.type != ngran_gNB_DU) {
      continue;
    }
    const seq_report_sty_t *style = find_rc_common_information_style(node);
    if (style == NULL) {
      continue;
    }

    assert(handle_count < MAX_E2_NODES);
    expected[expected_count++] = &node->id;
    rc_sub_data_t subscription = make_rc_cell_discovery_subscription(style);
    handles[handle_count] = report_sm_xapp_api(&node->id, SM_RC_ID, &subscription, sm_cb_rc_cell_discovery);
    assert(handles[handle_count].success);
    ++handle_count;
    free_rc_sub_data(&subscription);
  }

  if (expected_count > 0) {
    struct timespec deadline = {0};
    int rc = clock_gettime(CLOCK_REALTIME, &deadline);
    assert(rc == 0);
    deadline.tv_sec += wait_ms / 1000;
    deadline.tv_nsec += (long)(wait_ms % 1000) * 1000000L;
    if (deadline.tv_nsec >= 1000000000L) {
      ++deadline.tv_sec;
      deadline.tv_nsec -= 1000000000L;
    }

    rc = pthread_mutex_lock(&kpm_cell_mutex);
    assert(rc == 0);
    while (discovered_du_count(expected, expected_count) < expected_count && rc == 0) {
      rc = pthread_cond_timedwait(&kpm_cell_condition, &kpm_cell_mutex, &deadline);
    }
    assert((rc == 0 || rc == ETIMEDOUT) && "Failed while waiting for DU cell discovery");
    const size_t discovered = discovered_du_count(expected, expected_count);
    rc = pthread_mutex_unlock(&kpm_cell_mutex);
    assert(rc == 0);
    printf("[xApp] Discovered NR CGI information for %zu of %zu DU(s) through E2SM-RC\n", discovered, expected_count);
  }

  for (size_t i = 0; i < handle_count; i++) {
    rm_report_sm_xapp_api(handles[i].u.handle);
  }
}

static bool cell_belongs_to_cu(const kpm_cell_info_t *cell, const global_e2_node_id_t *cu_node_id) {
  return eq_e2ap_plmn(&cell->du_node_id.plmn, &cu_node_id->plmn) &&
         eq_e2ap_gnb_id(cell->du_node_id.nb_id, cu_node_id->nb_id);
}

static kpm_cell_info_t *snapshot_kpm_cells(const global_e2_node_id_t *cu_node_id, size_t *count) {
  int rc = pthread_mutex_lock(&kpm_cell_mutex);
  assert(rc == 0);
  *count = 0;
  for (size_t i = 0; i < kpm_cell_count; i++) {
    *count += cell_belongs_to_cu(&kpm_cells[i], cu_node_id);
  }

  kpm_cell_info_t *snapshot = *count == 0 ? NULL : ecalloc(*count, sizeof(*snapshot));
  size_t next = 0;
  for (size_t i = 0; i < kpm_cell_count; i++) {
    if (cell_belongs_to_cu(&kpm_cells[i], cu_node_id)) {
      snapshot[next].du_node_id = cp_global_e2_node_id(&kpm_cells[i].du_node_id);
      snapshot[next].cgi = cp_cell_global_id(&kpm_cells[i].cgi);
      ++next;
    }
  }
  rc = pthread_mutex_unlock(&kpm_cell_mutex);
  assert(rc == 0);
  return snapshot;
}

static void free_kpm_cells(kpm_cell_info_t *cells, size_t count) {
  for (size_t i = 0; i < count; i++) {
    free_global_e2_node_id(&cells[i].du_node_id);
    free_cell_global_id(&cells[i].cgi);
  }
  free(cells);
}

static bool has_discovered_kpm_cell(const global_e2_node_id_t *du_node_id) {
  int rc = pthread_mutex_lock(&kpm_cell_mutex);
  assert(rc == 0);
  bool found = false;
  for (size_t i = 0; i < kpm_cell_count; i++) {
    if (eq_global_e2_node_id(&kpm_cells[i].du_node_id, du_node_id)) {
      found = true;
      break;
    }
  }
  rc = pthread_mutex_unlock(&kpm_cell_mutex);
  assert(rc == 0);
  return found;
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

static kpm_act_def_format_1_t make_kpm_action_format_1(const ric_report_style_item_t *report_item, uint64_t period_ms,
                                                       const cell_global_id_t *cgi) {
  kpm_act_def_format_1_t format = {0};
  // [1, 65535]
  format.meas_info_lst_len = report_item->meas_info_for_action_lst_len;
  format.meas_info_lst = ecalloc(format.meas_info_lst_len, sizeof(*format.meas_info_lst));
  for (size_t i = 0; i < format.meas_info_lst_len; i++) {
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
  if (cgi != NULL) {
    format.cell_global_id = ecalloc(1, sizeof(*format.cell_global_id));
    *format.cell_global_id = cp_cell_global_id(cgi);
  }
#if defined KPM_V2_03 || defined KPM_V3_00
  // [0, 65535]
  format.meas_bin_range_info_lst_len = 0;
  format.meas_bin_info_lst = NULL;
#endif
  return format;
}

static kpm_act_def_t make_kpm_action(const ric_report_style_item_t *report_item, kpm_subscription_config_t config,
                                     const ue_id_e2sm_t *ues, size_t ue_count, const cell_global_id_t *cgi) {
  switch (report_item->report_style_type) {
  case STYLE_1_RIC_SERVICE_REPORT:
    assert(report_item->act_def_format_type == FORMAT_1_ACTION_DEFINITION);
    return (kpm_act_def_t){.type = FORMAT_1_ACTION_DEFINITION,
                           .frm_1 = make_kpm_action_format_1(report_item, config.period_ms, cgi)};
  case STYLE_2_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_2_ACTION_DEFINITION);
    assert(ue_count >= 1);
    kpm_act_def_t action = {.type = FORMAT_2_ACTION_DEFINITION};
    action.frm_2.ue_id = cp_ue_id_e2sm(&ues[0]);
    action.frm_2.action_def_format_1 = make_kpm_action_format_1(report_item, config.period_ms, NULL);
    return action;
  }
  case STYLE_3_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_3_ACTION_DEFINITION);
    kpm_act_def_t action = {.type = FORMAT_3_ACTION_DEFINITION};
    action.frm_3.meas_info_lst_len = report_item->meas_info_for_action_lst_len;
    action.frm_3.meas_info_lst = ecalloc(action.frm_3.meas_info_lst_len, sizeof(*action.frm_3.meas_info_lst));
    for (size_t i = 0; i < action.frm_3.meas_info_lst_len; i++) {
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
    action.frm_4.action_def_format_1 = make_kpm_action_format_1(report_item, config.period_ms, NULL);
    return action;
  }
  case STYLE_5_RIC_SERVICE_REPORT: {
    assert(report_item->act_def_format_type == FORMAT_5_ACTION_DEFINITION);
    assert(ue_count >= 2);
    kpm_act_def_t action = {.type = FORMAT_5_ACTION_DEFINITION};
    action.frm_5.ue_id_lst_len = ue_count;
    action.frm_5.ue_id_lst = ecalloc(ue_count, sizeof(*action.frm_5.ue_id_lst));
    for (size_t i = 0; i < ue_count; i++) {
      action.frm_5.ue_id_lst[i] = cp_ue_id_e2sm(&ues[i]);
    }
    action.frm_5.action_def_format_1 = make_kpm_action_format_1(report_item, config.period_ms, NULL);
    return action;
  }
  default:
    assert(false && "Unsupported KPM report style");
  }
  return (kpm_act_def_t){0};
}

static size_t required_kpm_ues(ric_service_report_e report_style) {
  if (report_style == STYLE_2_RIC_SERVICE_REPORT) {
    return 1;
  }
  if (report_style == STYLE_5_RIC_SERVICE_REPORT) {
    return 2;
  }
  return 0;
}

static kpm_sub_data_t make_kpm_subscription(const kpm_ran_function_def_t *ran_function,
                                            const ric_report_style_item_t *report_item,
                                            kpm_subscription_config_t config, const ue_id_e2sm_t *ues, size_t ue_count,
                                            const cell_global_id_t *cgi) {
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
  *subscription.ad = make_kpm_action(report_item, config, ues, ue_count, cgi);
  return subscription;
}

sm_ran_function_t *kpm_find_ran_function(e2_node_connected_xapp_t *node, uint32_t ran_function_id) {
  for (size_t i = 0; i < node->len_rf; i++) {
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
                                const ue_id_e2sm_t *ues, size_t ue_count, const cell_global_id_t *cgi, sm_cb callback,
                                sm_ans_xapp_t *handle) {
  const size_t required_ues = required_kpm_ues(report_item->report_style_type);
  printf("[xApp] Subscribing to KPM report style %d", report_item->report_style_type + 1);
  if (required_ues != 0) {
    printf(" with %zu discovered UE ID(s)",
           report_item->report_style_type == STYLE_2_RIC_SERVICE_REPORT ? 1 : ue_count);
  }
  if (cgi != NULL && cgi->type == NR_CGI_RAT_TYPE) {
    printf(" for NR Cell ID %" PRIu64, (uint64_t)cgi->nr_cgi.nr_cell_id);
  }
  printf(".\n");

  // Generate KPM SUBSCRIPTION message
  kpm_sub_data_t subscription = make_kpm_subscription(&ran_function->defn.kpm, report_item, config, ues, ue_count, cgi);
  *handle = report_sm_xapp_api(&node->id, ran_function->id, &subscription, callback);
  assert(handle->success);
  free_kpm_sub_data(&subscription);
}

static bool kpm_report_style_enabled(kpm_subscription_config_t config, ric_service_report_e report_style) {
  return config.report_style_mask == 0 || (config.report_style_mask & (UINT32_C(1) << report_style)) != 0;
}

static bool kpm_report_style_has_measurement(const ric_report_style_item_t *report_item, const char *name) {
  for (size_t i = 0; i < report_item->meas_info_for_action_lst_len; i++) {
    if (cmp_str_ba(name, report_item->meas_info_for_action_lst[i].name) == 0) {
      return true;
    }
  }
  return false;
}

static bool has_kpm_sinr_source(const e2_node_arr_xapp_t *nodes, uint32_t ran_function_id,
                                const global_e2_node_id_t *du_node_id) {
  for (size_t i = 0; i < nodes->len; i++) {
    const e2_node_connected_xapp_t *node = &nodes->n[i];
    if ((node->id.type != ngran_gNB_CU && node->id.type != ngran_gNB_CUCP) ||
        !eq_e2ap_plmn(&node->id.plmn, &du_node_id->plmn) || !eq_e2ap_gnb_id(node->id.nb_id, du_node_id->nb_id)) {
      continue;
    }
    for (size_t j = 0; j < node->len_rf; j++) {
      if (node->rf[j].id != ran_function_id || node->rf[j].defn.type != KPM_RAN_FUNC_DEF_E) {
        continue;
      }
      const kpm_ran_function_def_t *definition = &node->rf[j].defn.kpm;
      for (size_t k = 0; k < definition->sz_ric_report_style_list; k++) {
        const ric_report_style_item_t *style = &definition->ric_report_style_list[k];
        if (style->report_style_type == STYLE_1_RIC_SERVICE_REPORT &&
            kpm_report_style_has_measurement(style, "MR.NRScSSSINR")) {
          return true;
        }
      }
    }
  }
  return false;
}

static bool node_supports_kpm_report_style(const e2_node_connected_xapp_t *node, uint32_t ran_function_id,
                                           ric_service_report_e report_style) {
  for (size_t i = 0; i < node->len_rf; i++) {
    if (node->rf[i].id != ran_function_id || node->rf[i].defn.type != KPM_RAN_FUNC_DEF_E) {
      continue;
    }
    const kpm_ran_function_def_t *definition = &node->rf[i].defn.kpm;
    for (size_t j = 0; j < definition->sz_ric_report_style_list; j++) {
      if (definition->ric_report_style_list[j].report_style_type == report_style) {
        return true;
      }
    }
  }
  return false;
}

static bool has_kpm_ue_join_source(const e2_node_arr_xapp_t *nodes, uint32_t ran_function_id,
                                   const global_e2_node_id_t *node_id) {
  if (!is_kpm_du_node(node_id) && !is_kpm_cu_node(node_id)) {
    return false;
  }
  for (size_t i = 0; i < nodes->len; i++) {
    const e2_node_connected_xapp_t *candidate = &nodes->n[i];
    if (is_kpm_du_node(node_id) == is_kpm_du_node(&candidate->id) ||
        (!is_kpm_du_node(&candidate->id) && !is_kpm_cu_node(&candidate->id)) ||
        !same_kpm_gnb(node_id, &candidate->id)) {
      continue;
    }
    if (node_supports_kpm_report_style(candidate, ran_function_id, STYLE_4_RIC_SERVICE_REPORT)) {
      return true;
    }
  }
  return false;
}

kpm_subscription_set_t kpm_subscribe_report_styles(const e2_node_arr_xapp_t *nodes, uint32_t ran_function_id,
                                                   kpm_subscription_config_t config, sm_cb callback) {
  assert(nodes != NULL);
  assert(callback != NULL);

  kpm_set_e2_node_topology(nodes);
  if (kpm_report_style_enabled(config, STYLE_1_RIC_SERVICE_REPORT)) {
    discover_kpm_cells(nodes, config.ue_wait_ms);
  }

  kpm_subscription_set_t subscriptions = {.node_count = nodes->len};
  subscriptions.handles = ecalloc(nodes->len, sizeof(*subscriptions.handles));
  subscriptions.handle_counts = ecalloc(nodes->len, sizeof(*subscriptions.handle_counts));

  for (size_t i = 0; i < nodes->len; i++) {
    e2_node_connected_xapp_t *node = &nodes->n[i];
    sm_ran_function_t *ran_function = kpm_find_ran_function(node, ran_function_id);
    const size_t report_style_count = ran_function->defn.kpm.sz_ric_report_style_list;
    subscriptions.handles[i] = ecalloc(report_style_count + MAX_E2_NODES, sizeof(*subscriptions.handles[i]));

    // if REPORT Service is supported by E2 node, send SUBSCRIPTION
    // e.g. OAI CU-CP
    for (size_t j = 0; j < report_style_count; j++) {
      ric_report_style_item_t *report_item = &ran_function->defn.kpm.ric_report_style_list[j];
      assert(report_item->report_style_type < END_RIC_SERVICE_REPORT);
      if (!kpm_report_style_enabled(config, report_item->report_style_type)) {
        continue;
      }
      if (required_kpm_ues(report_item->report_style_type) != 0) {
        continue;
      }

      if (report_item->report_style_type == STYLE_1_RIC_SERVICE_REPORT &&
          (node->id.type == ngran_gNB_CU || node->id.type == ngran_gNB_CUCP) &&
          kpm_report_style_has_measurement(report_item, "MR.NRScSSSINR")) {
        size_t cell_count = 0;
        kpm_cell_info_t *cells = snapshot_kpm_cells(&node->id, &cell_count);
        if (cell_count > 0) {
          for (size_t cell = 0; cell < cell_count; cell++) {
            const size_t index = subscriptions.handle_counts[i]++;
            sm_cb cell_callback =
                reserve_kpm_cell_callback(callback, &cells[cell].du_node_id, config.period_ms * UINT64_C(500));
            subscribe_kpm_style(node, ran_function, report_item, config, NULL, 0, &cells[cell].cgi, cell_callback,
                                &subscriptions.handles[i][index]);
          }
          free_kpm_cells(cells, cell_count);
          continue;
        }
        free_kpm_cells(cells, cell_count);
      }

      const size_t index = subscriptions.handle_counts[i]++;
      sm_cb report_callback = callback;
      if (report_item->report_style_type == STYLE_1_RIC_SERVICE_REPORT && node->id.type == ngran_gNB_DU &&
          has_discovered_kpm_cell(&node->id) && has_kpm_sinr_source(nodes, ran_function_id, &node->id)) {
        report_callback = reserve_kpm_cell_callback(callback, &node->id, config.period_ms * UINT64_C(500));
      } else if (report_item->report_style_type == STYLE_4_RIC_SERVICE_REPORT &&
                 has_kpm_ue_join_source(nodes, ran_function_id, &node->id)) {
        report_callback = reserve_kpm_ue_callback(callback, config.period_ms * UINT64_C(500));
      }
      subscribe_kpm_style(node, ran_function, report_item, config, NULL, 0, NULL, report_callback,
                          &subscriptions.handles[i][index]);
    }
  }

  for (size_t i = 0; i < nodes->len; i++) {
    e2_node_connected_xapp_t *node = &nodes->n[i];
    sm_ran_function_t *ran_function = kpm_find_ran_function(node, ran_function_id);
    const size_t report_style_count = ran_function->defn.kpm.sz_ric_report_style_list;
    size_t max_required_ues = 0;
    for (size_t j = 0; j < report_style_count; j++) {
      const ric_service_report_e report_style = ran_function->defn.kpm.ric_report_style_list[j].report_style_type;
      if (!kpm_report_style_enabled(config, report_style)) {
        continue;
      }
      const size_t required = required_kpm_ues(report_style);
      if (required > max_required_ues) {
        max_required_ues = required;
      }
    }
    if (max_required_ues == 0) {
      continue;
    }

    const size_t discovered = wait_for_kpm_ues(&node->id, max_required_ues, config.ue_wait_ms);
    size_t ue_count = 0;
    ue_id_e2sm_t *ues = snapshot_kpm_ues(&node->id, &ue_count);
    printf("[xApp] Discovered %zu UE ID(s) for UE-specific KPM subscriptions%s.\n", ue_count,
           discovered < max_required_ues ? " before the discovery timeout" : "");

    for (size_t j = 0; j < report_style_count; j++) {
      ric_report_style_item_t *report_item = &ran_function->defn.kpm.ric_report_style_list[j];
      if (!kpm_report_style_enabled(config, report_item->report_style_type)) {
        continue;
      }
      const size_t required = required_kpm_ues(report_item->report_style_type);
      if (required == 0) {
        continue;
      }
      if (ue_count < required) {
        printf("[xApp] KPM report style %d deferred: it requires at least %zu discovered UE ID(s).\n",
               report_item->report_style_type + 1, required);
        continue;
      }
      const size_t index = subscriptions.handle_counts[i]++;
      subscribe_kpm_style(node, ran_function, report_item, config, ues, ue_count, NULL, callback,
                          &subscriptions.handles[i][index]);
    }
    free_kpm_ue_list(ues, ue_count);
  }

  return subscriptions;
}

void kpm_unsubscribe_report_styles(kpm_subscription_set_t *subscriptions) {
  if (subscriptions == NULL) {
    return;
  }
  for (size_t i = 0; i < subscriptions->node_count; i++) {
    for (size_t j = 0; j < subscriptions->handle_counts[i]; j++) {
      // Remove the handle previously returned
      if (subscriptions->handles[i][j].success) {
        rm_report_sm_xapp_api(subscriptions->handles[i][j].u.handle);
      }
    }
    free(subscriptions->handles[i]);
  }
  free(subscriptions->handles);
  free(subscriptions->handle_counts);
  *subscriptions = (kpm_subscription_set_t){0};
}
