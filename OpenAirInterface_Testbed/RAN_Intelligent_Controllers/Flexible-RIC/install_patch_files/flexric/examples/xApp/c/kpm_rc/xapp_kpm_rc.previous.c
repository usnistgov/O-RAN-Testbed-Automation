/*
 * Licensed to the OpenAirInterface (OAI) Software Alliance under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The OpenAirInterface Software Alliance licenses this file to You under
 * the OAI Public License, Version 1.1  (the "License"); you may not use this file
 * except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.openairinterface.org/?page_id=698
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *-------------------------------------------------------------------------------
 * For more information about the OpenAirInterface (OAI) Software Alliance:
 *      contact@openairinterface.org
 */

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/sm/rc_sm/ie/ir/ran_param_struct.h"
#include "../../../../src/sm/rc_sm/ie/ir/ran_param_list.h"
#include "../../../../src/util/time_now_us.h"
#include "../../../../src/util/alg_ds/alg/murmur_hash_32.h"
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"
#include "../../../../src/util/alg_ds/ds/assoc_container/assoc_generic.h"
#include "../../../../src/util/e.h"
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>

static
ue_id_e2sm_t ue_id;

static
uint64_t const period_ms = 100;

static
pthread_mutex_t mtx;

static
assoc_ht_open_t ht = {0};

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
}

static
void log_du_ue_id(ue_id_e2sm_t ue_id)
{
  printf("UE ID type = gNB-DU, gnb_cu_ue_f1ap = %u\n", ue_id.gnb_du.gnb_cu_ue_f1ap);
  if (ue_id.gnb_du.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb_du.ran_ue_id); // RAN UE NGAP ID
  }
}

static
void log_cuup_ue_id(ue_id_e2sm_t ue_id)
{
  printf("UE ID type = gNB-CU-UP, gnb_cu_cp_ue_e1ap = %u\n", ue_id.gnb_cu_up.gnb_cu_cp_ue_e1ap);
  if (ue_id.gnb_cu_up.ran_ue_id != NULL) {
    printf("ran_ue_id = %lx\n", *ue_id.gnb_cu_up.ran_ue_id); // RAN UE NGAP ID
  }
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
  char *name_unit = get_meas_unit(name_str);
  if (label_info.noLabel != NULL) {
    printf("%s = %d %s\n", name_str, meas_record.int_val, name_unit);
  } else if (label_info.distBinX != NULL && meas_record.int_val > 0) {
    printf("%s[BinX=%d][BinY=%d][BinZ=%d] = %d %s\n", name_str, *label_info.distBinX, *label_info.distBinY, *label_info.distBinZ, meas_record.int_val, name_unit);
  }
}

static
void log_real_value(const char *name_str, const label_info_lst_t label_info, const meas_record_lst_t meas_record)
{
  (void)label_info;
  char *name_unit = get_meas_unit(name_str);
  printf("%s = %.2f %s\n", name_str, meas_record.real_val, name_unit);
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

  // UE Measurements per granularity period
  for (size_t j = 0; j < msg_frm_1->meas_data_lst_len; j++) {
    meas_data_lst_t const data_item = msg_frm_1->meas_data_lst[j];

    for (size_t i = 0; i < msg_frm_1->meas_info_lst_len; i++) {
      const meas_info_format_1_lst_t info_item = msg_frm_1->meas_info_lst[i];
      for (size_t z = 0; z < info_item.label_info_lst_len; z++) {
        const label_info_lst_t label_info = info_item.label_info_lst[z];
        const meas_record_lst_t record_item = data_item.meas_record_lst[i + z];

        match_meas_type[info_item.meas_type.type](info_item.meas_type, label_info, record_item);

        if (data_item.incomplete_flag && *data_item.incomplete_flag == TRUE_ENUM_VALUE)
          printf("Measurement Record not reliable");
      }
    }
  }
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
}

typedef enum {
  DRB_QoS_Configuration_7_6_2_1 = 1,
  QoS_flow_mapping_configuration_7_6_2_1 = 2,
  Logical_channel_configuration_7_6_2_1 = 3,
  Radio_admission_control_7_6_2_1 = 4,
  DRB_termination_control_7_6_2_1 = 5,
  DRB_split_ratio_control_7_6_2_1 = 6,
  PDCP_Duplication_control_7_6_2_1 = 7,
} rc_ctrl_service_style_1_e;

typedef enum {
  DRB_ID_8_4_2_2 = 1,
  LIST_OF_QOS_FLOWS_MOD_IN_DRB_8_4_2_2 = 2,
  QOS_FLOW_ITEM_8_4_2_2 = 3,
  QOS_FLOW_ID_8_4_2_2 = 4,
  QOS_FLOW_MAPPING_IND_8_4_2_2 = 5,
} qos_flow_mapping_conf_e;

static
seq_ran_param_t fill_drb_id_param(void)
{
  seq_ran_param_t drb_param = {0};

  drb_param.ran_param_id = DRB_ID_8_4_2_2;
  drb_param.ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  drb_param.ran_param_val.flag_true = calloc(1, sizeof(ran_parameter_value_t));
  assert(drb_param.ran_param_val.flag_true != NULL && "Memory exhausted");
  // Let's suppose that it is the DRB 5
  drb_param.ran_param_val.flag_true->type = INTEGER_RAN_PARAMETER_VALUE;
  drb_param.ran_param_val.flag_true->int_ran = 5;

  return drb_param;
}

static
seq_ran_param_t fill_qos_flows_param(void)
{
  seq_ran_param_t qos_param = {0};

  qos_param.ran_param_id = LIST_OF_QOS_FLOWS_MOD_IN_DRB_8_4_2_2;
  qos_param.ran_param_val.type = LIST_RAN_PARAMETER_VAL_TYPE;
  qos_param.ran_param_val.lst = calloc(1, sizeof(ran_param_list_t));
  assert(qos_param.ran_param_val.lst != NULL && "Memory exhausted");
  ran_param_list_t* rpl = qos_param.ran_param_val.lst;

  rpl->sz_lst_ran_param = 1;
  rpl->lst_ran_param = calloc(1, sizeof(lst_ran_param_t));
  assert(rpl->lst_ran_param != NULL && "Memory exhausted");

  // QoS Flow Item
  // Bug in the standard. RAN Parameter List 9.3.13
  // has a mandatory ie RAN Parameter ID 9.3.8
  // and a mandatory ie RAN Parameter Structure 9.3.12
  // However, the ASN
  // RANParameter-LIST ::= SEQUENCE {
  // list-of-ranParameter  SEQUENCE (SIZE(1..maxnoofItemsinList)) OF RANParameter-STRUCTURE,
  // ..
  // }
  //
  // Misses RAN Parameter ID and only has RAN Parameter Structure

  // rpl->lst_ran_param[0].ran_param_id = QOS_FLOW_ITEM_8_4_2_2;

  rpl->lst_ran_param[0].ran_param_struct.sz_ran_param_struct = 2;
  rpl->lst_ran_param[0].ran_param_struct.ran_param_struct = calloc(2, sizeof(seq_ran_param_t));
  assert(rpl->lst_ran_param[0].ran_param_struct.ran_param_struct != NULL && "Memory exhausted");
  seq_ran_param_t* rps = rpl->lst_ran_param[0].ran_param_struct.ran_param_struct;

  // QoS Flow Identifier
  rps[0].ran_param_id = QOS_FLOW_ID_8_4_2_2;
  rps[0].ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  rps[0].ran_param_val.flag_true = calloc(1, sizeof(ran_parameter_value_t));
  assert(rps[0].ran_param_val.flag_true != NULL && "Memory exhausted");
  rps[0].ran_param_val.flag_true->type = INTEGER_RAN_PARAMETER_VALUE;
  // Let's suppose that we have QFI 10
  rps[0].ran_param_val.flag_true->int_ran = 10;

  // QoS Flow Mapping Indication
  rps[1].ran_param_id = QOS_FLOW_MAPPING_IND_8_4_2_2;
  rps[1].ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  rps[1].ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(rps[1].ran_param_val.flag_false != NULL && "Memory exhausted");

  // ENUMERATED (ul, dl, ...)
  rps[1].ran_param_val.flag_false->type = INTEGER_RAN_PARAMETER_VALUE;
  rps[1].ran_param_val.flag_false->int_ran = 1;

  return qos_param;
}

static
void fill_rc_ctrl_act(seq_ctrl_act_2_t const* ctrl_act,
                             size_t const sz,
                             e2sm_rc_ctrl_hdr_frmt_1_t* hdr,
                             e2sm_rc_ctrl_msg_frmt_1_t* msg)
{
  assert(ctrl_act != NULL);

  for (size_t i = 0; i < sz; i++) {
    assert(cmp_str_ba("QoS flow mapping configuration", ctrl_act[i].name) == 0 && "Add requested CONTROL Action. At the moment, only QoS flow mapping configuration supported");

    hdr->ctrl_act_id = QoS_flow_mapping_configuration_7_6_2_1;

    msg->sz_ran_param = ctrl_act[i].sz_seq_assoc_ran_param;
    assert(msg->sz_ran_param == 2);
    msg->ran_param = calloc(msg->sz_ran_param, sizeof(seq_ran_param_t));
    assert(msg->ran_param != NULL && "Memory exhausted");

    /* Fill RAN Parameters in Control Message */

    // DRB ID
    assert(ctrl_act[i].assoc_ran_param[0].id == DRB_ID_8_4_2_2);
    msg->ran_param[0] = fill_drb_id_param();

    // List of QoS Flows to be modified in DRB
    assert(ctrl_act[i].assoc_ran_param[1].id == LIST_OF_QOS_FLOWS_MOD_IN_DRB_8_4_2_2);
    msg->ran_param[1] = fill_qos_flows_param();
  }
}

static
rc_ctrl_req_data_t gen_rc_ctrl_msg(ran_func_def_ctrl_t const* ran_func)
{
  assert(ran_func != NULL);

  rc_ctrl_req_data_t rc_ctrl = {0};

  for (size_t i = 0; i < ran_func->sz_seq_ctrl_style; i++) {
    assert(cmp_str_ba("Radio Bearer Control", ran_func->seq_ctrl_style[i].name) == 0 && "Add requested CONTROL Style. At the moment, only Radio Bearer Control supported");

    // CONTROL HEADER
    rc_ctrl.hdr.format = ran_func->seq_ctrl_style[i].hdr;
    assert(rc_ctrl.hdr.format == FORMAT_1_E2SM_RC_CTRL_HDR && "Indication Header Format received not valid");
    rc_ctrl.hdr.frmt_1.ric_style_type = 1;
    // 6.2.2.6
    {
      lock_guard(&mtx);
      rc_ctrl.hdr.frmt_1.ue_id = cp_ue_id_e2sm(&ue_id);
    }

    // CONTROL MESSAGE
    rc_ctrl.msg.format = ran_func->seq_ctrl_style[i].msg;
    assert(rc_ctrl.msg.format == FORMAT_1_E2SM_RC_CTRL_MSG && "Indication Message Format received not valid");

    fill_rc_ctrl_act(ran_func->seq_ctrl_style[i].seq_ctrl_act,
                     ran_func->seq_ctrl_style[i].sz_seq_ctrl_act,
                     &rc_ctrl.hdr.frmt_1,
                     &rc_ctrl.msg.frmt_1);
  }

  return rc_ctrl;
}

static
test_info_lst_t filter_predicate(test_cond_type_e type, test_cond_e cond, int value)
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
  const size_t len_nssai = 1;
  dst.test_cond_value->octet_string_value->len = len_nssai;
  dst.test_cond_value->octet_string_value->buf = calloc(len_nssai, sizeof(uint8_t));
  assert(dst.test_cond_value->octet_string_value->buf != NULL && "Memory exhausted");
  dst.test_cond_value->octet_string_value->buf[0] = value;

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

  // Fill matching condition
  // [1, 32768]
  act_def.frm_4.matching_cond_lst_len = 1;
  act_def.frm_4.matching_cond_lst = calloc(act_def.frm_4.matching_cond_lst_len, sizeof(matching_condition_format_4_lst_t));
  assert(act_def.frm_4.matching_cond_lst != NULL && "Memory exhausted");
  // Filter connected UEs by S-NSSAI criteria
  test_cond_type_e const type = S_NSSAI_TEST_COND_TYPE; // CQI_TEST_COND_TYPE
  test_cond_e const condition = EQUAL_TEST_COND; // GREATERTHAN_TEST_COND
  int const value = 1;
  act_def.frm_4.matching_cond_lst[0].test_info_lst = filter_predicate(type, condition, value);

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
  fr_args_t args = init_fr_args(argc, argv);

  // Init the xApp
  init_xapp_api(&args);
  sleep(1);

  init_kpm_meas_unit_hash_table();

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  assert(nodes.len > 0);

  printf("[KPM RC]: Connected E2 nodes = %d\n", nodes.len);

  pthread_mutexattr_t attr = {0};
  int rc = pthread_mutex_init(&mtx, &attr);
  assert(rc == 0);

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

  sleep(5);

  ////////////
  // START RC
  ////////////
  int const RC_ran_function = 3;

  for (size_t i = 0; i < nodes.len; ++i) {
    e2_node_connected_xapp_t* n = &nodes.n[i];

    size_t const idx = find_sm_idx(n->rf, n->len_rf, eq_sm, RC_ran_function);
    assert(n->rf[idx].defn.type == RC_RAN_FUNC_DEF_E && "RC is not the received RAN Function");
    // if CONTROL Service is supported by E2 node, send CONTROL message
    if (n->rf[idx].defn.rc.ctrl != NULL) {
      // Generate RC CONTROL message
      rc_ctrl_req_data_t rc_ctrl = gen_rc_ctrl_msg(n->rf[idx].defn.rc.ctrl);

      control_sm_xapp_api(&n->id, RC_ran_function, &rc_ctrl);

      free_rc_ctrl_req_data(&rc_ctrl);
    }
  }
  ////////////
  // END RC
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

  free_e2_node_arr_xapp(&nodes);

  rc = pthread_mutex_destroy(&mtx);
  assert(rc == 0);

  printf("[KPM RC]: Test xApp run SUCCESSFULLY\n");
}
