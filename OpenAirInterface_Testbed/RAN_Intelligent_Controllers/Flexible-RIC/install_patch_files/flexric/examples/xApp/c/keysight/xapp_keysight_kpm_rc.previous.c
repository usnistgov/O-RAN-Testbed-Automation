/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/sm/rc_sm/ie/ir/ran_param_struct.h"
#include "../../../../src/sm/rc_sm/ie/ir/ran_param_list.h"
#include "../../../../src/util/time_now_us.h"
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>

static uint64_t period_ms = 1000;

static byte_array_t copy_str_to_ba(const char *str)
{
  assert(str != NULL);

  size_t const sz = strlen(str);
  byte_array_t dst = {.len = sz};
  dst.buf = calloc(sz, sizeof(uint8_t));
  assert(dst.buf != NULL);

  memcpy(dst.buf, str, sz);

  return dst;
}

static bool ctrl_msg_call_once = true;
static pthread_mutex_t mtx;

static gnb_e2sm_t target_ue_id_list[102] = {0};
static int64_t target_drb_id_list[102] = {0};
static int64_t total_num_ues = 0;

static uint32_t last_prb_usage_dl = {0};

static uint32_t last_dl_thp_gbr_matched[5] = {0};
static gnb_e2sm_t matched_ue_id_list[5] = {0};
static int64_t num_matched_ues_dl = 0;

static uint32_t thp_list_gbr_critical[200] = {0};
static uint32_t gbr_critical_num_values = 0;

static uint32_t thp_list_gbr_streaming[200] = {0};
static uint32_t gbr_streaming_num_values = 0;

static uint32_t thp_list_non_gbr[200] = {0};
static uint32_t non_gbr_num_values = 0;

static uint32_t prb_usage_all[200] = {0};


static int64_t get_matched_drb_id(const gnb_e2sm_t gnb_ue_id)
{
  int64_t matched_drb_id = 0;

  for (int64_t j = 0; j < total_num_ues; j++)
  {
    if (eq_gnb_ue_id_e2sm(&gnb_ue_id, &target_ue_id_list[j]) == true)
    {
      matched_drb_id = target_drb_id_list[j];
      break;
    }
  }

  return matched_drb_id;
}

////////////
// Get RC Indication Messages -> begin
////////////

static void sm_cb_rc(sm_ag_if_rd_t const *rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == RAN_CTRL_STATS_V1_03);

  // Reading Indication Message Format 2
  e2sm_rc_ind_msg_frmt_2_t const *msg_frm_2 = &rd->ind.rc.ind.msg.frmt_2;

  printf("\n RC REPORT Style 2 - Call Process Outcome\n");

  // Sequence of UE Identifier
  //[1-65535]
  for (size_t i = 0; i < msg_frm_2->sz_seq_ue_id; i++)
  {
    // UE ID
    // Mandatory
    // 9.3.10
    switch (msg_frm_2->seq_ue_id[i].ue_id.type)
    {
    case GNB_UE_ID_E2SM:
      printf("UE connected to gNB with amf_ue_ngap_id = %lu\n", msg_frm_2->seq_ue_id[i].ue_id.gnb.amf_ue_ngap_id);
      // Add UE[i] to the targeting list
      target_ue_id_list[total_num_ues] = cp_gnb_ue_id_e2sm(&msg_frm_2->seq_ue_id[i].ue_id.gnb);
      break;

    default:
      assert(false && "Not yet implemented UE ID type");
    }

    // Sequence of
    // RAN Parameter
    // [1- 65535]
    if (msg_frm_2->seq_ue_id[i].seq_ran_param[1].ran_param_val.strct->ran_param_struct[0].ran_param_val.lst->lst_ran_param[0].ran_param_struct.ran_param_struct[0].ran_param_val.strct->ran_param_struct[2].ran_param_val.lst->lst_ran_param[0].ran_param_struct.ran_param_struct[0].ran_param_val.strct->ran_param_struct[0].ran_param_id == 21546)
    {
      // printf("DRB ID = %lu\n", msg_frm_2->seq_ue_id[i].seq_ran_param[1].ran_param_val.strct->ran_param_struct[0].ran_param_val.lst->lst_ran_param[0].ran_param_struct.ran_param_struct[0].ran_param_val.strct->ran_param_struct[2].ran_param_val.lst->lst_ran_param[0].ran_param_struct.ran_param_struct[0].ran_param_val.strct->ran_param_struct[0].ran_param_val.flag_true->int_ran);
      target_drb_id_list[total_num_ues++] = msg_frm_2->seq_ue_id[i].seq_ran_param[1].ran_param_val.strct->ran_param_struct[0].ran_param_val.lst->lst_ran_param[0].ran_param_struct.ran_param_struct[0].ran_param_val.strct->ran_param_struct[2].ran_param_val.lst->lst_ran_param[0].ran_param_struct.ran_param_struct[0].ran_param_val.strct->ran_param_struct[0].ran_param_val.flag_true->int_ran;
    }
    else
    {
      assert(false && "No DRB ID element in RC Indication Message");
    }
  }
}

////////////
// Get RC Indication Messages -> end
////////////


////////////
// Get KPM Indication Messages -> begin
////////////

static void sm_cb_kpm_1(sm_ag_if_rd_t const *rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0);

  // Reading Indication Message Format 1
  kpm_ind_msg_format_1_t const *msg_frm_1 = &rd->ind.kpm.ind.msg.frm_1;

  static int counter_1 = 1;
  printf("\n%7d KPM Style 1 - Cell-level measurements\nperiod = %lu [ms]\n", counter_1, period_ms);

  for (size_t j = 0; j < msg_frm_1->meas_data_lst_len; j++)
  {
    for (size_t z = 0; z < msg_frm_1->meas_data_lst[j].meas_record_len; z++)
    {
      if (msg_frm_1->meas_info_lst_len > 0)
      {
        switch (msg_frm_1->meas_info_lst[z].meas_type.type)
        {
        case NAME_MEAS_TYPE:
        {
          // Get the Measurement Name
          char meas_info_name_str[msg_frm_1->meas_info_lst[z].meas_type.name.len + 1];
          memcpy(meas_info_name_str, msg_frm_1->meas_info_lst[z].meas_type.name.buf, msg_frm_1->meas_info_lst[z].meas_type.name.len);
          meas_info_name_str[msg_frm_1->meas_info_lst[z].meas_type.name.len] = '\0';

          // Get the value of the Measurement
          switch (msg_frm_1->meas_data_lst[j].meas_record_lst[z].value)
          {
          case INTEGER_MEAS_VALUE:
          {
            if (strcmp(meas_info_name_str, "RRU.PrbTotDl") == 0)
            {
              printf("RRU.PrbTotDl = %d [%%]\n", msg_frm_1->meas_data_lst[j].meas_record_lst[z].int_val);
              lock_guard(&mtx);
              last_prb_usage_dl = msg_frm_1->meas_data_lst[j].meas_record_lst[z].int_val;
              prb_usage_all[counter_1-1] = msg_frm_1->meas_data_lst[j].meas_record_lst[z].int_val;
            }
            else if (strcmp(meas_info_name_str, "RRU.PrbTotUl") == 0)
            {
              // printf("RRU.PrbTotUl = %d [%%]\n", msg_frm_1->meas_data_lst[j].meas_record_lst[z].int_val);
            }
            else
            {
              printf("Measurement Name not yet implemented\n");
              // assert(false && "Measurement Name not yet implemented");
            }

            break;
          }

          default:
            assert("Value not recognized");
          }

          break;
        }

        default:
          assert(false && "Measurement Type not yet implemented");
        }
      }
      if (msg_frm_1->meas_data_lst[j].incomplete_flag && *msg_frm_1->meas_data_lst[j].incomplete_flag == TRUE_ENUM_VALUE)
        printf("Measurement Record not reliable\n");
    }
  }
  counter_1++;
}


static void sm_cb_kpm_3(sm_ag_if_rd_t const *rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0);

  // Reading Indication Message Format 2
  kpm_ind_msg_format_2_t const *msg_frm_2 = &rd->ind.kpm.ind.msg.frm_2;

  static int counter_3 = 1;
  printf("\n%7d KPM Style 3 - Condition based, UE-level measurements\nperiod = %lu [ms]\n", counter_3, period_ms);

  assert(msg_frm_2->meas_data_lst_len == 1 && "Check the granularity period, should be equal to reporting period (Keysight limitation)");

  for (size_t i = 0; i < msg_frm_2->meas_info_cond_ue_lst_len; i++) // equal to 2, UL/DL thr
  {
    // Matching Condition
    for (size_t j = 0; j < msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst_len; j++)
    {
      switch (msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[j].cond_type)
      {
      case LABEL_INFO:
      {
        printf("Matching condition type is Label Information\n");
        break;
      }
      case TEST_INFO:
      {
        assert(msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[j].test_info_lst.test_cond_type == GBR_TEST_COND_TYPE);
        assert(*msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[j].test_info_lst.test_cond == LESSTHAN_TEST_COND);
        assert(msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[j].test_info_lst.test_cond_value->type == INTEGER_TEST_COND_VALUE);
        printf("Test Condition: GBR rate < %lu\n", *msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[j].test_info_lst.test_cond_value->int_value);

        break;
      }

      default:
        assert(false && "Not yet implemented");
      }
    }

    // List of Matched UEs
    if (msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst != NULL)
    {
      num_matched_ues_dl = 0;
      // num_others_ues = 0;

      for (size_t j = 0; j < msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst_len; j++)
      {
        switch (msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst[j].type)
        {
        case GNB_UE_ID_E2SM:
          printf("#%ld UE connected to gNB with amf_ue_ngap_id = %lu\n", j + 1, msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst[j].gnb.amf_ue_ngap_id);
          break;

        case GNB_DU_UE_ID_E2SM:
          printf("#%ld UE connected to gNB-DU with gnb_cu_ue_f1ap = %u\n", j + 1, msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst[j].gnb_du.gnb_cu_ue_f1ap);
          break;

        default:
          assert(false && "Not yet implemented UE ID type");
        }

        switch (msg_frm_2->meas_info_cond_ue_lst[i].meas_type.type)
        {
        case NAME_MEAS_TYPE:
        {
          // Get the Measurement Name
          char meas_info_name_str[msg_frm_2->meas_info_cond_ue_lst[i].meas_type.name.len + 1];
          memcpy(meas_info_name_str, msg_frm_2->meas_info_cond_ue_lst[i].meas_type.name.buf, msg_frm_2->meas_info_cond_ue_lst[i].meas_type.name.len);
          meas_info_name_str[msg_frm_2->meas_info_cond_ue_lst[i].meas_type.name.len] = '\0';

          // Get the value of the Measurement
          switch (msg_frm_2->meas_data_lst[0].meas_record_lst[j].value)
          {
          case INTEGER_MEAS_VALUE:
          {
            if (strcmp(meas_info_name_str, "DRB.UEThpDl") == 0)
            {
              printf("DRB.UEThpDl = %d [kb/s]\n", msg_frm_2->meas_data_lst[0].meas_record_lst[j].int_val);
            }
            else if (strcmp(meas_info_name_str, "DRB.UEThpUl") == 0)
            {
              printf("DRB.UEThpUl = %d [kb/s]\n", msg_frm_2->meas_data_lst[0].meas_record_lst[j + msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst_len].int_val);
            }
            else if (strcmp(meas_info_name_str, "DRB.UEThpDl.QOS") == 0)
            {
              printf("DRB.UEThpDl.QOS = %d [kb/s], with 5QI = %hhu\n", msg_frm_2->meas_data_lst[0].meas_record_lst[j].int_val, *msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[0].label_info_lst.fiveQI);
              assert(num_matched_ues_dl >= 0 && num_matched_ues_dl < 5);

              if (*msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[0].label_info_lst.fiveQI == 131){
                last_dl_thp_gbr_matched[num_matched_ues_dl] = msg_frm_2->meas_data_lst[0].meas_record_lst[j].int_val;
                matched_ue_id_list[num_matched_ues_dl++] = cp_gnb_ue_id_e2sm(&msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst[j].gnb);
                if (j == 0)
                  thp_list_gbr_critical[20+(gbr_critical_num_values++)] = msg_frm_2->meas_data_lst[0].meas_record_lst[j].int_val;
              }
              else if (*msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[0].label_info_lst.fiveQI == 4) {
                if (j == 0)
                  thp_list_gbr_streaming[gbr_streaming_num_values++] = msg_frm_2->meas_data_lst[0].meas_record_lst[j].int_val;
              }
              else if (*msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[0].label_info_lst.fiveQI == 9) {
                if (j == 0)
                  thp_list_non_gbr[non_gbr_num_values++] = msg_frm_2->meas_data_lst[0].meas_record_lst[j].int_val;
              }
            }
            else if (strcmp(meas_info_name_str, "DRB.UEThpUl.QOS") == 0)
            {
              // printf("DRB.UEThpUl.QOS = %d [kb/s], with 5QI = %hhu\n", msg_frm_2->meas_data_lst[0].meas_record_lst[j + msg_frm_2->meas_info_cond_ue_lst[i].ue_id_matched_lst_len].int_val, *msg_frm_2->meas_info_cond_ue_lst[i].matching_cond_lst[0].label_info_lst.fiveQI);
            }
            break;
          }

          default:
            assert("Value not recognized");
          }

          break;
        }

        default:
          assert(false && "Measurement Type not yet implemented");
        }
      }
    }
    else
    {
      printf("No matched UEs with this test condition\n");
    }
  }

  if (msg_frm_2->meas_data_lst[0].incomplete_flag && *msg_frm_2->meas_data_lst[0].incomplete_flag == TRUE_ENUM_VALUE)
    printf("Measurement Record not reliable\n");


  counter_3++;
}

////////////
// Get KPM Indication Messages -> end
////////////

////////////
// Reserved for KPM SM -> begin
////////////

static meas_info_format_1_lst_t gen_meas_info_frm_1_cell_lst(const char *act)
{
  meas_info_format_1_lst_t dst = {0};

  dst.meas_type.type = NAME_MEAS_TYPE;
  dst.meas_type.name = copy_str_to_ba(act);

  dst.label_info_lst_len = 1;
  dst.label_info_lst = calloc(1, sizeof(label_info_lst_t));
  assert(dst.label_info_lst != NULL && "Memory exhausted");
  dst.label_info_lst[0].noLabel = calloc(1, sizeof(enum_value_e));
  assert(dst.label_info_lst[0].noLabel != NULL && "Memory exhausted");
  *dst.label_info_lst[0].noLabel = TRUE_ENUM_VALUE;

  return dst;
}

static kpm_act_def_format_1_t gen_act_def_frm_1_cell(const char **act)
{
  kpm_act_def_format_1_t dst = {0};

  dst.gran_period_ms = period_ms;

  // [1, 65535]
  size_t count = 0;
  while (act[count] != NULL)
  {
    count++;
  }
  dst.meas_info_lst_len = count;
  dst.meas_info_lst = calloc(count, sizeof(meas_info_format_1_lst_t));
  assert(dst.meas_info_lst != NULL && "Memory exhausted");

  for (size_t i = 0; i < dst.meas_info_lst_len; i++)
  {
    dst.meas_info_lst[i] = gen_meas_info_frm_1_cell_lst(act[i]);
  }

  return dst;
}

static matching_condition_format_3_lst_t gen_matching_cond_frm_3_lst(const char *act, const uint8_t five_qi)
{
  matching_condition_format_3_lst_t dst = {0};

  // Label information list as matching condition
  dst.cond_type = LABEL_INFO;

  if (strcmp(act, "DRB.UEThpDl.QOS") == 0 || strcmp(act, "DRB.UEThpUl.QOS") == 0)
  {
    dst.label_info_lst.fiveQI = calloc(1, sizeof(uint8_t));
    assert(dst.label_info_lst.fiveQI != NULL && "Memory exhausted");
    *dst.label_info_lst.fiveQI = five_qi;
  }
  else
  {
    assert(false && "Not yet implemented");
  }

  return dst;
}

static meas_info_format_3_lst_t gen_meas_info_format_3_lst(const char *act, const uint8_t five_qi)
{
  meas_info_format_3_lst_t dst = {0};

  // Measurement Type
  dst.meas_type.type = NAME_MEAS_TYPE;
  dst.meas_type.name = copy_str_to_ba(act);

  // Matching Condition List [1, 32768]
  dst.matching_cond_lst_len = 1;
  dst.matching_cond_lst = calloc(dst.matching_cond_lst_len, sizeof(matching_condition_format_3_lst_t));
  assert(dst.matching_cond_lst != NULL && "Memory exhausted");

  for (size_t i = 0; i < dst.matching_cond_lst_len; i++)
  {
    dst.matching_cond_lst[i] = gen_matching_cond_frm_3_lst(act, five_qi);
  }

  // Bin Range Definition
  // Optional
  dst.bin_range_def = NULL;

  return dst;
}

static kpm_act_def_format_3_t gen_act_def_frm_3_ue(const char **act, const uint8_t five_qi)
{
  kpm_act_def_format_3_t dst = {0};

  // Measurement Information List [1, 65535]
  size_t count = 0;
  while (act[count] != NULL)
  {
    count++;
  }
  dst.meas_info_lst_len = count;
  dst.meas_info_lst = calloc(dst.meas_info_lst_len, sizeof(meas_info_format_3_lst_t));
  assert(dst.meas_info_lst != NULL && "Memory exhausted");

  for (size_t i = 0; i < dst.meas_info_lst_len; i++)
  {
    dst.meas_info_lst[i] = gen_meas_info_format_3_lst(act[i], five_qi);
  }

  // Granularity Period
  // Mandatory
  dst.gran_period_ms = period_ms;

  // Cell Global ID
  // Optional
  dst.cell_global_id = NULL;

  return dst;
}

static kpm_event_trigger_def_t gen_ev_trig(uint64_t period)
{
  kpm_event_trigger_def_t dst = {0};

  dst.type = FORMAT_1_RIC_EVENT_TRIGGER;
  dst.kpm_ric_event_trigger_format_1.report_period_ms = period;

  return dst;
}

static kpm_sub_data_t gen_kpm_sub_style_1(void)
{
  kpm_sub_data_t kpm_sub = {0};

  // Generate Event Trigger
  kpm_sub.ev_trg_def = gen_ev_trig(period_ms);

  // Generate Action Definition
  kpm_sub.sz_ad = 1;
  kpm_sub.ad = calloc(1, sizeof(kpm_act_def_t));
  assert(kpm_sub.ad != NULL && "Memory exhausted");

  const char *act_cell[] = {"RRU.PrbTotDl", "RRU.PrbTotUl", NULL}; // 3GPP TS 28.552
  kpm_sub.ad[0].type = FORMAT_1_ACTION_DEFINITION;
  kpm_sub.ad[0].frm_1 = gen_act_def_frm_1_cell(act_cell);

  return kpm_sub;
}

static kpm_sub_data_t gen_kpm_sub_style_3(const uint8_t five_qi)
{
  kpm_sub_data_t kpm_sub = {0};

  // Generate Event Trigger
  kpm_sub.ev_trg_def = gen_ev_trig(period_ms);

  // Generate Action Definition
  kpm_sub.sz_ad = 1;
  kpm_sub.ad = calloc(1, sizeof(kpm_act_def_t));
  assert(kpm_sub.ad != NULL && "Memory exhausted");

  const char *act_ue[] = {"DRB.UEThpDl.QOS", NULL}; // 3GPP TS 28.552
  kpm_sub.ad[0].type = FORMAT_3_ACTION_DEFINITION;
  kpm_sub.ad[0].frm_3 = gen_act_def_frm_3_ue(act_ue, five_qi);

  return kpm_sub;
}

////////////
// Reserved for KPM SM -> end
////////////


////////////
// Reserved for RC SM -> begin
////////////


static ue_id_e2sm_t gen_ue_id(gnb_e2sm_t const *gnb)
{
  ue_id_e2sm_t ue_id = {0};

  ue_id.type = GNB_UE_ID_E2SM;
  ue_id.gnb = cp_gnb_ue_id_e2sm(gnb);

  return ue_id;
}

typedef enum
{
  DRB_QoS_Configuration_7_6_2_1 = 1,
  QoS_flow_mapping_configuration_7_6_2_1 = 2,
  Logical_channel_configuration_7_6_2_1 = 3,
  Radio_admission_control_7_6_2_1 = 4,
  DRB_termination_control_7_6_2_1 = 5,
  DRB_split_ratio_control_7_6_2_1 = 6,
  PDCP_Duplication_control_7_6_2_1 = 7,
} rc_ctrl_service_style_1_e;

static e2sm_rc_ctrl_hdr_frmt_1_t gen_rc_ctrl_hdr_frmt_1(gnb_e2sm_t const *gnb)
{
  e2sm_rc_ctrl_hdr_frmt_1_t dst = {0};

  // UE ID
  // Mandatory
  // 9.3.10
  dst.ue_id = gen_ue_id(gnb);

  // CONTROL Service Style 1: Radio Bearer Control
  dst.ric_style_type = 1;

  // Control Action ID: DRB QoS Configuration
  // Mandatory
  // 9.3.6
  dst.ctrl_act_id = DRB_QoS_Configuration_7_6_2_1;

  // RIC Control decision
  // Optional - included only if this action is sent as response to Insert Indication
  dst.ric_ctrl_decision = NULL;

  return dst;
}

static e2sm_rc_ctrl_hdr_t gen_rc_ctrl_hdr(gnb_e2sm_t const *gnb)
{
  e2sm_rc_ctrl_hdr_t dst = {0};
  // Radio Bearer Control
  dst.format = FORMAT_1_E2SM_RC_CTRL_HDR;
  dst.frmt_1 = gen_rc_ctrl_hdr_frmt_1(gnb);
  return dst;
}

typedef enum
{
  DRB_ID_8_4_2_1 = 1,
  FIVEQI_8_4_2_1 = 2,
  PACKET_DELAY_BUDGET_8_4_2_1 = 3,
  PACKET_ERROR_RATE_8_4_2_1 = 4,
  SCALAR_FACTOR_8_4_2_1 = 5,
  EXPONENT_FACTOR_8_4_2_1 = 6,
  NG_RAN_DRB_ALLOC_AND_RETENTION_PRIORITY_8_4_2_1 = 7,
  PRIORITY_LEVEL_8_4_2_1 = 8,
  PRE_EMPTION_CAPABILITY_8_4_2_1 = 9,
  PRE_EMPTION_VULNERABILITY_8_4_2_1 = 10,
  PRIORITY_LEVEL_OF_MAPPED_QOS_FLOWS_8_4_2_1 = 11,
  QOS_PARAMETERS_FOR_GBR_FLOWS_IN_NG_RAN_BEARER_8_4_2_1 = 12,
  MAXIMUM_FLOW_BIT_RATE_DOWNLINK_8_4_2_1 = 13,
  GUARANTEED_FLOW_BIT_RATE_DOWNLINK_8_4_2_1 = 14,
  MAXIMUM_PACKET_LOSS_RATE_DOWNLINK_8_4_2_1 = 15,
  MAXIMUM_FLOW_BIT_RATE_UPLINK_8_4_2_1 = 16,
  GUARANTEED_FLOW_BIT_RATE_UPLINK_8_4_2_1 = 17,
  MAXIMUM_PACKET_LOSS_RATE_UPLINK_8_4_2_1 = 18,
  QOS_MONITORING_ENABLE_REQUEST_8_4_2_1 = 19,
  QOS_MONITORING_REPORTING_FREQUENCY_8_4_2_1 = 20,
  QOS_MONITORING_DISABLED_8_4_2_1 = 21,
  REFLECTIVE_QOS_MAPPING_8_4_2_1 = 22,
} drb_qos_conf_e;

static e2sm_rc_ctrl_msg_frmt_1_t gen_rc_ctrl_msg_frmt_1(int64_t const drb_id)
{
  e2sm_rc_ctrl_msg_frmt_1_t dst = {0};

  // 8.4.2.1 DRB QoS Configuration
  dst.sz_ran_param = 3;
  dst.ran_param = calloc(dst.sz_ran_param, sizeof(seq_ran_param_t));
  assert(dst.ran_param != NULL && "Memory exhausted");

  // DRB ID RAN Parameter
  dst.ran_param[0].ran_param_id = DRB_ID_8_4_2_1;
  dst.ran_param[0].ran_param_val.type = ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE;
  dst.ran_param[0].ran_param_val.flag_true = calloc(1, sizeof(ran_parameter_value_t));
  assert(dst.ran_param[0].ran_param_val.flag_true != NULL && "Memory exhausted");
  // Let's suppose that it is the DRB 1
  dst.ran_param[0].ran_param_val.flag_true->type = INTEGER_RAN_PARAMETER_VALUE;
  dst.ran_param[0].ran_param_val.flag_true->int_ran = drb_id;

  // Priority level of mapped QoS flows RAN Parameter
  dst.ran_param[1].ran_param_id = PRIORITY_LEVEL_OF_MAPPED_QOS_FLOWS_8_4_2_1;
  dst.ran_param[1].ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  dst.ran_param[1].ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(dst.ran_param[1].ran_param_val.flag_false != NULL && "Memory exhausted");
  dst.ran_param[1].ran_param_val.flag_false->type = INTEGER_RAN_PARAMETER_VALUE;
  dst.ran_param[1].ran_param_val.flag_false->int_ran = 1;

  // QoS parameters for GBR flows in NG-RAN Bearer RAN Parameter
  dst.ran_param[2].ran_param_id = QOS_PARAMETERS_FOR_GBR_FLOWS_IN_NG_RAN_BEARER_8_4_2_1;
  dst.ran_param[2].ran_param_val.type = STRUCTURE_RAN_PARAMETER_VAL_TYPE;
  dst.ran_param[2].ran_param_val.strct = calloc(1, sizeof(ran_param_struct_t));
  assert(dst.ran_param[2].ran_param_val.strct != NULL && "Memory exhausted");
  ran_param_struct_t *rps = dst.ran_param[2].ran_param_val.strct;

  rps->sz_ran_param_struct = 4;
  rps->ran_param_struct = calloc(rps->sz_ran_param_struct, sizeof(seq_ran_param_t));
  assert(rps->ran_param_struct != NULL && "Memory exhausted");

  // Maximum Flow Bit Rate DL RAN Parameter
  rps->ran_param_struct[0].ran_param_id = MAXIMUM_FLOW_BIT_RATE_DOWNLINK_8_4_2_1;
  rps->ran_param_struct[0].ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  rps->ran_param_struct[0].ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(rps->ran_param_struct[0].ran_param_val.flag_false != NULL && "Memory exhausted");
  rps->ran_param_struct[0].ran_param_val.flag_false->type = INTEGER_RAN_PARAMETER_VALUE;
  rps->ran_param_struct[0].ran_param_val.flag_false->int_ran = 40000;

  // Maximum Flow Bit Rate UL RAN Parameter
  rps->ran_param_struct[1].ran_param_id = MAXIMUM_FLOW_BIT_RATE_UPLINK_8_4_2_1;
  rps->ran_param_struct[1].ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  rps->ran_param_struct[1].ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(rps->ran_param_struct[1].ran_param_val.flag_false != NULL && "Memory exhausted");
  rps->ran_param_struct[1].ran_param_val.flag_false->type = INTEGER_RAN_PARAMETER_VALUE;
  rps->ran_param_struct[1].ran_param_val.flag_false->int_ran = 100;

  // Guaranteed Flow Bit Rate DL RAN Parameter
  rps->ran_param_struct[2].ran_param_id = GUARANTEED_FLOW_BIT_RATE_DOWNLINK_8_4_2_1;
  rps->ran_param_struct[2].ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  rps->ran_param_struct[2].ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(rps->ran_param_struct[2].ran_param_val.flag_false != NULL && "Memory exhausted");
  rps->ran_param_struct[2].ran_param_val.flag_false->type = INTEGER_RAN_PARAMETER_VALUE;
  rps->ran_param_struct[2].ran_param_val.flag_false->int_ran = 40000;

  // Guaranteed Flow Bit Rate UL RAN Parameter
  rps->ran_param_struct[3].ran_param_id = GUARANTEED_FLOW_BIT_RATE_UPLINK_8_4_2_1;
  rps->ran_param_struct[3].ran_param_val.type = ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE;
  rps->ran_param_struct[3].ran_param_val.flag_false = calloc(1, sizeof(ran_parameter_value_t));
  assert(rps->ran_param_struct[3].ran_param_val.flag_false != NULL && "Memory exhausted");
  rps->ran_param_struct[3].ran_param_val.flag_false->type = INTEGER_RAN_PARAMETER_VALUE;
  rps->ran_param_struct[3].ran_param_val.flag_false->int_ran = 100;

  return dst;
}

static e2sm_rc_ctrl_msg_t gen_rc_ctrl_msg(int64_t const drb_id)
{
  e2sm_rc_ctrl_msg_t dst = {0};

  // Radio Bearer Control
  dst.format = FORMAT_1_E2SM_RC_CTRL_MSG;
  dst.frmt_1 = gen_rc_ctrl_msg_frmt_1(drb_id);

  return dst;
}

static e2sm_rc_ev_trg_frmt_2_t gen_rc_event_trigger_frm_2(void)
{
  e2sm_rc_ev_trg_frmt_2_t ev_trigger = {0};

  //  Call Process Type ID
  //  Mandatory
  //  9.3.15
  ev_trigger.call_proc_type_id = 2; // Bearer Context Management

  // Call Breakpoint ID
  // Mandatory
  // 9.3.49
  ev_trigger.call_break_id = 1; // Bearer Context Setup

  // Associated E2 Node Info
  // Optional
  // 9.3.29
  ev_trigger.assoc_e2_node_info = NULL;

  // Associated UE Info
  // Optional
  // 9.3.26
  ev_trigger.assoc_ue_info = NULL;

  return ev_trigger;
}

typedef enum
{
  CURRENT_UE_ID_8_2_2 = 1,
  OLD_UE_ID_8_2_2 = 2,
  CURRENT_RRC_STATE_8_2_2 = 3,
  OLD_RRC_STATE_8_2_2 = 4,
  UE_CONTEXT_INFO_CONTAINER_8_2_2 = 5,
  CELL_GLOBAL_ID_8_2_2 = 6,
  UE_INFORMATION_8_2_2 = 7,
  MASTER_NODE_8_1_1_17 = 21501,
  GNB_MEASUREMENTS_MASTER_NODE_8_1_1_17 = 21502,
  CHOICE_PRIMARY_CELL_OF_MCG_8_1_1_17 = 21503,
  NR_CELL_PRIMARY_MCG_8_1_1_17 = 21504,
  EUTRA_CELL_PRIMARY_MCG_8_1_1_17 = 21505,
  LIST_OF_SECONDARY_CELLS_OF_MCG_8_1_1_17 = 21506,
  SCELL_ITEM_MCG_8_1_1_17 = 21507,
  CHOICE_SCELL_MSG_8_1_1_17 = 21508,
  NR_CELL_SECONDARY_MCG_8_1_1_17 = 21509,
  EUTRA_CELL_SECONDARY_MCG_8_1_1_17 = 21510,
  SECONDARY_NODE_8_1_1_17 = 21511,
  GNB_MEASUREMENTS_SECONDARY_NODE_8_1_1_17 = 21512,
  CHOICE_PRIMARY_CELL_OF_SCG_8_1_1_17 = 21513,
  NR_CELL_PRIMARY_SCG_8_1_1_17 = 21514,
  EUTRA_CELL_PRIMARY_SCG_8_1_1_17 = 21515,
  LIST_OF_SECONDARY_CELLS_OF_SCG_8_1_1_17 = 21516,
  SCELL_ITEM_SCG_8_1_1_17 = 21517,
  CHOICE_SCELL_SCG_8_1_1_17 = 21518,
  NR_CELL_SECONDARY_SCG_8_1_1_17 = 21519,
  EUTRA_CELL_SECONDARY_SCG_8_1_1_17 = 21520,
  LIST_OF_PDU_SESSIONS_8_1_1_17 = 21521,
  PDU_SESSION_ITEM_8_1_1_17 = 21522,
  PDU_SESSION_ID_8_1_1_17 = 21543,
  PDU_SESSION_8_1_1_17 = 21523,
  LIST_OF_DRBS_8_1_1_17 = 21524,
  DRB_ITEM_8_1_1_17 = 21525,
  DRB_ID_8_1_1_17 = 21546,
  DRB_8_1_1_17 = 21547,
  LIST_OF_QOS_FLOWS_MAPPED_TO_DRB_8_1_1_17 = 21526,
  QOS_FLOW_ITEM_8_1_1_17 = 21527,
  QOS_FLOW_IDENTIFIER_8_1_1_17 = 21548,
  QOS_FLOW_8_1_1_17 = 21549,
  LIST_OF_NEIGHBOR_CELLS_8_1_1_17 = 21528,
  NEIGHBOR_CELL_ITEM_8_1_1_17 = 21529,
  CHOICE_NEIGHBOR_CELL_8_1_1_17 = 21530,
  NR_CELL_NEIGHBOR_8_1_1_17 = 21531,
  EUTRA_CELL_NEIGHBOR_8_1_1_17 = 21532,

} ran_param_report_style_2_e;

static e2sm_rc_act_def_frmt_1_t gen_rc_act_def_frm_1(void)
{
  e2sm_rc_act_def_frmt_1_t act_def_frm_1 = {0};

  // Parameters to be Reported List
  // [1-65535]
  // 8.2.2
  act_def_frm_1.sz_param_report_def = 2;
  act_def_frm_1.param_report_def = calloc(act_def_frm_1.sz_param_report_def, sizeof(param_report_def_t));
  assert(act_def_frm_1.param_report_def != NULL && "Memory exhausted");

  // Current UE ID RAN Parameter
  act_def_frm_1.param_report_def[0].ran_param_id = CURRENT_UE_ID_8_2_2;
  act_def_frm_1.param_report_def[0].ran_param_def = NULL; // current ue id is element, optional

  // UE information RAN Parameter
  act_def_frm_1.param_report_def[1].ran_param_id = UE_INFORMATION_8_2_2;
  act_def_frm_1.param_report_def[1].ran_param_def = calloc(1, sizeof(ran_param_def_t));
  assert(act_def_frm_1.param_report_def[1].ran_param_def != NULL && "Memory exhausted");
  // fill UE information
  act_def_frm_1.param_report_def[1].ran_param_def->type = LIST_RAN_PARAMETER_DEF_TYPE;
  act_def_frm_1.param_report_def[1].ran_param_def->lst = calloc(1, sizeof(ran_param_type_t));
  assert(act_def_frm_1.param_report_def[1].ran_param_def->lst != NULL && "Memory exhausted");

  act_def_frm_1.param_report_def[1].ran_param_def->lst->sz_ran_param = 1;
  act_def_frm_1.param_report_def[1].ran_param_def->lst->ran_param = calloc(act_def_frm_1.param_report_def[1].ran_param_def->lst->sz_ran_param, sizeof(ran_param_lst_struct_t));
  assert(act_def_frm_1.param_report_def[1].ran_param_def->lst->ran_param != NULL && "Memory exhausted");

  act_def_frm_1.param_report_def[1].ran_param_def->lst->ran_param[0].ran_param_id = LIST_OF_PDU_SESSIONS_8_1_1_17;
  act_def_frm_1.param_report_def[1].ran_param_def->lst->ran_param[0].ran_param_name.len = strlen("List of PDU Sessions");
  act_def_frm_1.param_report_def[1].ran_param_def->lst->ran_param[0].ran_param_name.buf = calloc(strlen("List of PDU Sessions") + 1, sizeof(char));
  memcpy(act_def_frm_1.param_report_def[1].ran_param_def->lst->ran_param[0].ran_param_name.buf, "List of PDU Sessions", strlen("List of PDU Sessions"));

  return act_def_frm_1;
}

static rc_sub_data_t gen_rc_sub_style_2(void)
{
  rc_sub_data_t rc_sub = {0};

  // Generate Event Trigger
  // 9.2.1.1.2
  rc_sub.et.format = FORMAT_2_E2SM_RC_EV_TRIGGER_FORMAT;
  rc_sub.et.frmt_2 = gen_rc_event_trigger_frm_2();

  // Generate Action Definition
  // 9.2.1.2.1
  rc_sub.sz_ad = 1;
  rc_sub.ad = calloc(rc_sub.sz_ad, sizeof(e2sm_rc_action_def_t));
  assert(rc_sub.ad != NULL && "Memory exhausted");

  rc_sub.ad[0].ric_style_type = 2; // 7.4.1

  rc_sub.ad[0].format = FORMAT_1_E2SM_RC_ACT_DEF;
  rc_sub.ad[0].frmt_1 = gen_rc_act_def_frm_1();

  return rc_sub;
}

////////////
// Reserved for RC SM -> end
////////////

static
sm_ans_xapp_t *kpm_handle;

static
sm_ans_xapp_t *rc_handle;

static void stop_and_exit()
{
  // Remove the handles previously returned
  for(int i = 0; i < 4; i++){
    rm_report_sm_xapp_api(kpm_handle[i].u.handle);
  }
  free(kpm_handle);

  rm_report_sm_xapp_api(rc_handle[0].u.handle);
  free(rc_handle);

  sleep(1);

  // Stop the xApp
  while (try_stop_xapp_api() == false)
    usleep(1000);

  int rc = pthread_mutex_destroy(&mtx);
  assert(rc == 0);

  exit(EXIT_SUCCESS);
}

static void sig_handler(int sig_num)
{
  printf("\nEnding the xApp with signal number = %d\n. Please, wait.", sig_num);
  // For the impatient, do not break my code
  static pthread_once_t once = PTHREAD_ONCE_INIT;
  pthread_once(&once, stop_and_exit);
}

int main(int argc, char *argv[])
{
  // Signal handler
  signal(SIGINT, sig_handler);

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

  ////////////
  // START RC REPORT
  ////////////
  const int RC_ran_function = 3;

  rc_handle = calloc(1, sizeof(sm_ans_xapp_t));
  assert(rc_handle != NULL && "Memory exhausted");

  // RC handle
  for (size_t i = 0; i < nodes.len; ++i)
  {

    for (size_t j = 0; j < nodes.n[i].len_rf; j++)
      printf("Registered node ID %d ran func id = %d \n ", nodes.n[i].id.nb_id.nb_id, nodes.n[i].rf[j].id);

    // RC REPORT Service Style 2: Call Process Outcome
    rc_sub_data_t rc_sub = gen_rc_sub_style_2();
    defer({ free_rc_sub_data(&rc_sub); });

    rc_handle[0] = report_sm_xapp_api(&nodes.n[i].id, RC_ran_function, &rc_sub, sm_cb_rc);

    assert(rc_handle[0].success == true);
  }
  ////////////
  // END RC REPORT
  ////////////


  ////////////
  // START KPM
  ////////////
  const int KPM_ran_function = 1;

  // KPM handle
  kpm_handle = calloc(4, sizeof(sm_ans_xapp_t));
  assert(kpm_handle != NULL && "Memory exhausted");

  printf("[xApp]: reporting period = %lu [ms]\n", period_ms);

  // KPM SUBSCRIPTION FOR CELL LEVEL MEASUREMENTS Style 1
  kpm_sub_data_t kpm_sub_1 = gen_kpm_sub_style_1();
  defer({ free_kpm_sub_data(&kpm_sub_1); });
  kpm_handle[0] = report_sm_xapp_api(&nodes.n[0].id, KPM_ran_function, &kpm_sub_1, sm_cb_kpm_1);
  assert(kpm_handle[0].success == true);

  // KPM SUBSCRIPTION FOR UE LEVEL MEASUREMENTS Style 3
  const uint8_t five_qi_matched = 131;
  kpm_sub_data_t kpm_sub_3_gbr_matched = gen_kpm_sub_style_3(five_qi_matched);
  defer({ free_kpm_sub_data(&kpm_sub_3_gbr_matched); });
  kpm_handle[1] = report_sm_xapp_api(&nodes.n[0].id, KPM_ran_function, &kpm_sub_3_gbr_matched, sm_cb_kpm_3);
  assert(kpm_handle[1].success == true);

  // SUBSCRIBE TO UE 1 AND 2 GBR
  const uint8_t five_qi_others = 4;
  kpm_sub_data_t kpm_sub_3_gbr_others = gen_kpm_sub_style_3(five_qi_others);
  defer({ free_kpm_sub_data(&kpm_sub_3_gbr_others); });
  kpm_handle[2] = report_sm_xapp_api(&nodes.n[0].id, KPM_ran_function, &kpm_sub_3_gbr_others, sm_cb_kpm_3);
  assert(kpm_handle[2].success == true);

    // SUBSCRIBE TO UE 301 AND 302 NON-GBR
  const uint8_t five_qi_non_gbr = 9;
  kpm_sub_data_t kpm_sub_3_non_gbr = gen_kpm_sub_style_3(five_qi_non_gbr);
  defer({ free_kpm_sub_data(&kpm_sub_3_non_gbr); });
  kpm_handle[3] = report_sm_xapp_api(&nodes.n[0].id, KPM_ran_function, &kpm_sub_3_non_gbr, sm_cb_kpm_3);
  assert(kpm_handle[3].success == true);


  ////////////
  // END KPM
  ////////////


  ////////////
  // START RC CONTROL
  ////////////
  
  while (ctrl_msg_call_once)
  {
    for (size_t i = 0; i < 5; i++)
    {
      uint32_t cp_last_dl_thp_gbr_matched = 0;
      gnb_e2sm_t cp_matched_ue_id = {0};
      defer({ free_gnb_ue_id_e2sm(&cp_matched_ue_id); });
      {
        lock_guard(&mtx);
        cp_matched_ue_id = cp_gnb_ue_id_e2sm(&matched_ue_id_list[i]);
        cp_last_dl_thp_gbr_matched = last_dl_thp_gbr_matched[i];
      }

      if(cp_last_dl_thp_gbr_matched >= 10000){
        // RC CONTROL Service Style 1
        rc_ctrl_req_data_t rc_ctrl = {0};
        defer({ free_rc_ctrl_req_data(&rc_ctrl); });

        rc_ctrl.hdr = gen_rc_ctrl_hdr(&cp_matched_ue_id);

        int64_t cp_matched_drb_id = get_matched_drb_id(cp_matched_ue_id);
        rc_ctrl.msg = gen_rc_ctrl_msg(cp_matched_drb_id);

        control_sm_xapp_api(&nodes.n[0].id, RC_ran_function, &rc_ctrl);
        printf("RC Control message Style 1 \"DRB QoS Configuration\" sent\n");

        ctrl_msg_call_once = false;
      }
    }
  }

  ////////////
  // END RC CONTROL
  ////////////

  sleep(100);

  // KPM and RC UNSUBSCRIPTION
  for(int i = 0; i < 4; i++){
    rm_report_sm_xapp_api(kpm_handle[i].u.handle);
  }
  free(kpm_handle);

  rm_report_sm_xapp_api(rc_handle[0].u.handle);
  free(rc_handle);


  // Stop the xApp
  while (try_stop_xapp_api() == false)
    usleep(1000);

  printf("Test xApp run SUCCESSFULLY\n");
}
