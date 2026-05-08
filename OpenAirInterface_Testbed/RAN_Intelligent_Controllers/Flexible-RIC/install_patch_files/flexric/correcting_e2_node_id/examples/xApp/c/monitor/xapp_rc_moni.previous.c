/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/util/alg_ds/alg/defer.h"
#include "../../../../src/util/time_now_us.h"
#include "../../../../src/util/alg_ds/ds/lock_guard/lock_guard.h"

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>

#include "NR_DL-DCCH-Message.h"
#include "NR_RRCReconfiguration.h"
#include "NR_CellGroupConfig.h"
#include "NR_UL-DCCH-Message.h"
#include "../../../../src/lib/sm/dec/dec_ue_id.h"

static
pthread_mutex_t mtx;

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

// Print integer value
static
void log_int_ran_param_value_rrc_state(int64_t value)
{
  if (value == RRC_CONNECTED_RRC_STATE_E2SM_RC) {
    printf("RAN Parameter Value = RRC connected\n");
  } else if (value == RRC_INACTIVE_RRC_STATE_E2SM_RC) {
    printf("RAN Parameter Value = RRC inactive\n");
  } else if (value == RRC_IDLE_RRC_STATE_E2SM_RC) {
    printf("RAN Parameter Value = RRC idle\n");
  }
}

static
void log_meas_report(const NR_MeasResults_t *results)
{
  for (int i = 0; i < results->measResultServingMOList.list.count; i++) {
    NR_MeasResultServMO_t *measresultservmo = results->measResultServingMOList.list.array[i];
    NR_MeasResultNR_t *measresultnr = &measresultservmo->measResultServingCell;
    NR_MeasQuantityResults_t *mqr = measresultnr->measResult.cellResults.resultsSSB_Cell;

    if (mqr != NULL) {
      char rrsrp[32], rrsrq[16], rsinr[16];

      if (mqr->rsrp)
        snprintf(rrsrp, sizeof(rrsrp), "%ld [dBm]", *mqr->rsrp - 156);
      else
        snprintf(rrsrp, sizeof(rrsrp), "not provided");

      if (mqr->rsrq)
        snprintf(rrsrq, sizeof(rrsrq), "%.1f [dB]", (*mqr->rsrq - 87) / 2.0f);
      else
        snprintf(rrsrq, sizeof(rrsrq), "not provided");

      if (mqr->sinr)
        snprintf(rsinr, sizeof(rsinr), "%.1f [dB]", (*mqr->sinr - 46) / 2.0f);
      else
        snprintf(rsinr, sizeof(rsinr), "not provided");

      printf("RSRP %s, RSRQ %s, SINR %s\n", rrsrp, rrsrq, rsinr);
    } else {
      printf("resultsSSB-Cell: empty.\n");
    }
  }
}

//Print Octet String value
static
void log_octet_str_ran_param_value(const e2sm_rc_ind_hdr_frmt_1_t *hdr, byte_array_t octet_str, uint32_t id)
{
  switch (id) {
    case E2SM_RC_RS1_RRC_MESSAGE:
      if (*hdr->ev_trigger_id == 1) {
        printf("\nDecode and print DL-DCCH message:\n");
        NR_DL_DCCH_Message_t *msg = NULL;
        asn_dec_rval_t dec_rval = uper_decode(NULL, &asn_DEF_NR_DL_DCCH_Message,
                                          (void **)&msg, octet_str.buf, octet_str.len, 0, 0);
        assert(dec_rval.code == RC_OK);
        xer_fprint(stdout, &asn_DEF_NR_DL_DCCH_Message, msg);
  
        assert(msg->message.present == NR_DL_DCCH_MessageType_PR_c1);
        assert(msg->message.choice.c1->present == NR_DL_DCCH_MessageType__c1_PR_rrcReconfiguration);
        NR_RRCReconfiguration_t *reconfig = msg->message.choice.c1->choice.rrcReconfiguration;
  
        assert(reconfig->criticalExtensions.present == NR_RRCReconfiguration__criticalExtensions_PR_rrcReconfiguration);
        NR_RRCReconfiguration_IEs_t *ies = reconfig->criticalExtensions.choice.rrcReconfiguration;
        assert(ies->nonCriticalExtension != NULL);
        assert(ies->nonCriticalExtension->masterCellGroup != NULL);
        OCTET_STRING_t *binary_cellGroupConfig = ies->nonCriticalExtension->masterCellGroup;
        NR_CellGroupConfig_t *cellGroupConfig = NULL;
        dec_rval = uper_decode(NULL, &asn_DEF_NR_CellGroupConfig,
                               (void **)&cellGroupConfig, binary_cellGroupConfig->buf,
                               binary_cellGroupConfig->size, 0, 0);
        assert(dec_rval.code == RC_OK);
        printf("\nDecode and print CellGroupConfig message:\n");
        xer_fprint(stdout, &asn_DEF_NR_CellGroupConfig, cellGroupConfig);
        ASN_STRUCT_FREE(asn_DEF_NR_DL_DCCH_Message, msg);
        ASN_STRUCT_FREE(asn_DEF_NR_CellGroupConfig, cellGroupConfig);
      } else if (*hdr->ev_trigger_id == 2 || *hdr->ev_trigger_id == 3 || *hdr->ev_trigger_id == 4) {
        printf("\nDecode and print UL-DCCH message:\n");
        NR_UL_DCCH_Message_t *msg = NULL;
        asn_dec_rval_t dec_rval = uper_decode(NULL, &asn_DEF_NR_UL_DCCH_Message,
                                          (void **)&msg, octet_str.buf, octet_str.len, 0, 0);
        assert(dec_rval.code == RC_OK);
        xer_fprint(stdout, &asn_DEF_NR_UL_DCCH_Message, msg);
        assert(msg->message.present == NR_UL_DCCH_MessageType_PR_c1);
        if (msg->message.choice.c1->present == NR_UL_DCCH_MessageType__c1_PR_measurementReport) {
          NR_MeasResults_t *results = &msg->message.choice.c1->choice.measurementReport->criticalExtensions.choice.measurementReport->measResults;
          if (results == NULL) {
            printf("Received RRC MeasaurementReport message but no measurements are filled.\n");
          } else {
            log_meas_report(results);
          }
        }
        ASN_STRUCT_FREE(asn_DEF_NR_UL_DCCH_Message, msg);
      }
      break;

    case E2SM_RC_RS1_UE_ID:
      if (*hdr->ev_trigger_id == 4) {
        printf("\"RRC Setup Complete\" message detected\n");
      } else if (*hdr->ev_trigger_id == 5) {
        printf("\"F1\" message detected\n");
      }
      UEID_t ue_id_asn = {0};
      defer({ ASN_STRUCT_RESET(asn_DEF_UEID, &ue_id_asn); });
      UEID_t* src_ref = &ue_id_asn;

      asn_dec_rval_t const ret = aper_decode(NULL, &asn_DEF_UEID, (void **)&src_ref, octet_str.buf, octet_str.len, 0, 0);
      assert(ret.code == RC_OK);

      ue_id_e2sm_t ue_id = dec_ue_id_asn(&ue_id_asn);
      ue_id_e2sm_e const ue_id_type = ue_id.type;
      log_ue_id ue_id_logger = log_ue_id_e2sm[ue_id_type];
      if (ue_id_logger) {
        ue_id_logger(ue_id);
      } else {
        printf("UE ID type %d logging not implemented\n", ue_id_type);
      }
      free_ue_id_e2sm(&ue_id);
      break;

    default:
      printf("Only decoding for RRC Message and UE ID is supported!\n");
  }
}

static
void log_element_ran_param_value(const e2sm_rc_ind_hdr_frmt_1_t *hdr, ran_parameter_value_t* param_value, uint32_t id)
{
  assert(param_value != NULL);

  switch (param_value->type) {
    case INTEGER_RAN_PARAMETER_VALUE:
      log_int_ran_param_value_rrc_state(param_value->int_ran);
      break;

    case OCTET_STRING_RAN_PARAMETER_VALUE:
      log_octet_str_ran_param_value(hdr, param_value->octet_str_ran, id);
      break;

    default:
      printf("Add corresponding print function for the RAN Parameter Value (other than Integer and Octet string)\n");
  }
}

static
void log_ran_param_name_frmt_1(uint32_t id)
{
  switch (id) {
    case E2SM_RC_RS1_RRC_MESSAGE:
      printf("RAN Parameter Name = RRC Message\n");
      break;

    case E2SM_RC_RS1_UE_ID:
      printf("RAN Parameter Name = UE ID\n");
      break;

    default:
      printf("Add corresponding RAN Parameter ID for REPORT Service Style 1\n");
  }
}

static
void log_ind_1_1(const e2sm_rc_ind_hdr_frmt_1_t *hdr, const e2sm_rc_ind_msg_frmt_1_t* msg)
{
  {
    lock_guard(&mtx);

    // List parameters
    for (size_t j = 0; j < msg->sz_seq_ran_param; j++) {
      seq_ran_param_t* const ran_param_item = &msg->seq_ran_param[j];

      log_ran_param_name_frmt_1(ran_param_item->ran_param_id);
      printf("RAN Parameter ID = %d\n", ran_param_item->ran_param_id);

      switch (ran_param_item->ran_param_val.type) {
        case ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE:
          log_element_ran_param_value(hdr, ran_param_item->ran_param_val.flag_false, ran_param_item->ran_param_id);
          break;

        case ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE:
          log_element_ran_param_value(hdr, ran_param_item->ran_param_val.flag_true, ran_param_item->ran_param_id);
          break;

        default:
          printf("Add corresponding function for the RAN Parameter Value Type (other than element)\n");
      }
    }
  }
}

static
void log_ran_param_name_frmt_2(uint32_t id)
{
  switch (id) {
    case E2SM_RC_RS4_RRC_STATE_CHANGED_TO:
      printf("RAN Parameter Name = RRC State Changed To\n");
      break;

    default:
      printf("Add corresponding RAN Parameter ID for REPORT Service Style 4\n");
  }
}

static
void log_ind_1_2(const e2sm_rc_ind_hdr_frmt_1_t *hdr, const e2sm_rc_ind_msg_frmt_2_t* msg)
{
  assert(hdr != NULL);

  {
    lock_guard(&mtx);

    for (size_t i = 0; i < msg->sz_seq_ue_id; i++) {
      seq_ue_id_t* const ue_id_item = &msg->seq_ue_id[i];

      ue_id_e2sm_e const ue_id_type = ue_id_item->ue_id.type;
      log_ue_id ue_id_logger = log_ue_id_e2sm[ue_id_type];
      if (ue_id_logger) {
        ue_id_logger(ue_id_item->ue_id);
      } else {
        printf("UE ID type %d logging not implemented\n", ue_id_type);
      }

      // List parameters
      for (size_t j = 0; j < ue_id_item->sz_seq_ran_param; j++) {
        seq_ran_param_t* const ran_param_item = &ue_id_item->seq_ran_param[j];

        log_ran_param_name_frmt_2(ran_param_item->ran_param_id);
        printf("RAN Parameter ID is: %d\n", ran_param_item->ran_param_id);

        switch (ran_param_item->ran_param_val.type) {
          case ELEMENT_KEY_FLAG_FALSE_RAN_PARAMETER_VAL_TYPE:
            log_element_ran_param_value(hdr, ran_param_item->ran_param_val.flag_false, ran_param_item->ran_param_id);
            break;

          case ELEMENT_KEY_FLAG_TRUE_RAN_PARAMETER_VAL_TYPE:
            log_element_ran_param_value(hdr, ran_param_item->ran_param_val.flag_true, ran_param_item->ran_param_id);
            break;

          default:
            printf("Add corresponding function for the RAN Parameter Value Type (other than element)\n");
        }
      }
    }
  }
}

static
void sm_cb_rc(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);

  static int counter = 1;
  printf("\n%7d RC Indication Message received:\n", counter);

  // log properly INDICATION formats
  const e2sm_rc_ind_hdr_format_e hdr_type = rd->ind.rc.ind.hdr.format;
  const e2sm_rc_ind_msg_format_e msg_type = rd->ind.rc.ind.msg.format;
  if (hdr_type == FORMAT_1_E2SM_RC_IND_HDR && msg_type == FORMAT_1_E2SM_RC_IND_MSG) {
    log_ind_1_1(&rd->ind.rc.ind.hdr.frmt_1, &rd->ind.rc.ind.msg.frmt_1);
  } else if (hdr_type == FORMAT_1_E2SM_RC_IND_HDR && msg_type == FORMAT_2_E2SM_RC_IND_MSG) {
    log_ind_1_2(&rd->ind.rc.ind.hdr.frmt_1, &rd->ind.rc.ind.msg.frmt_2);
  } else {
    printf("Unknown RIC indication message received.\n");
  }

  counter++;
}

static
rrc_state_lst_t fill_rrc_state_change(void)
{
  rrc_state_lst_t rrc_state_lst = {0};

  rrc_state_lst.sz_rrc_state = 1;
  rrc_state_lst.state_chng_to = calloc(rrc_state_lst.sz_rrc_state, sizeof(rrc_state_t));
  assert(rrc_state_lst.state_chng_to != NULL && "Memory exhausted");

  // 9.3.37
  rrc_state_lst.state_chng_to[0].state_chngd_to = ANY_RRC_STATE_E2SM_RC;

  // 9.3.25
  // Logical OR
  rrc_state_lst.state_chng_to[0].log_or = NULL;

  return rrc_state_lst;
}

static
ue_info_chng_t fill_ue_info_chng(ue_info_chng_trigger_type_e const trigger_type)
{
  ue_info_chng_t ue_info_chng = {0};

  //  Event Trigger Condition ID
  //  Mandatory
  //  9.3.21
  ue_info_chng.ev_trig_cond_id = 1; // this parameter contains rnd value, but must be matched in ind hdr
  /* For each information change configured, Event Trigger Condition ID is assigned
  so that E2 Node can reply to Near-RT RIC in the RIC INDICATION message to inform
  which event(s) are the cause for triggering. */

  // CHOICE Trigger Type
  ue_info_chng.type = trigger_type;

  switch (trigger_type) {
    case RRC_STATE_UE_INFO_CHNG_TRIGGER_TYPE: {
      // RRC State
      // 9.3.37
      ue_info_chng.rrc_state = fill_rrc_state_change();
      break;
    }

    default:
      assert(false && "Add requested Trigger Type. At the moment, only RRC State supported");
  }

  // Associated UE Info
  // Optional
  // 9.3.26
  ue_info_chng.assoc_ue_info = NULL;

  // Logical OR
  // Optional
  // 9.3.25
  ue_info_chng.log_or = NULL;

  return ue_info_chng;
}

static
param_report_def_t fill_param_report(uint32_t const ran_param_id, ran_param_def_t const* ran_param_def)
{
  param_report_def_t param_report = {0};

  // RAN Parameter ID
  // Mandatory
  // 9.3.8
  // [1 - 4294967295]
  param_report.ran_param_id = ran_param_id;

  // RAN Parameter Definition
  // Optional
  // 9.3.51
  if (ran_param_def != NULL) {
    param_report.ran_param_def = calloc(1, sizeof(ran_param_def_t));
    assert(param_report.ran_param_def != NULL && "Memory exhausted");
    *param_report.ran_param_def = cp_ran_param_def(ran_param_def);
  }

  return param_report;
}

static
rrc_msg_id_t fill_rrc_msg_id_3(const nr_rrc_class_e nr_class, const uint32_t msg_id)
{
  rrc_msg_id_t rrc_msg_id = {0};

  // CHOICE RRC Message Type
  rrc_msg_id.type = NR_RRC_MESSAGE_ID;

  rrc_msg_id.nr = nr_class; // RRC Message Class
  rrc_msg_id.rrc_msg_id = msg_id; // RRC Message ID

  return rrc_msg_id;
}

static
network_interface_e2rc_t fill_ni_msg_id_3(const network_interface_type_e class)
{
  network_interface_e2rc_t net = {0};

  // NI Type
  // Mandatory
  // 9.3.32
  net.ni_type = class;

  // NI Identifier
  // Optional
  // 9.3.33
  net.ni_id = NULL;

  // NI Message
  // Optional
  // 9.3.34
  net.ni_msg_id = NULL;

  return net;
}

static
msg_ev_trg_t fill_msg_ev_trig_3(msg_type_ev_trg_e const trigger_type, const uint16_t cond_id, const uint16_t class, const uint32_t msg_id)
{
  msg_ev_trg_t msg_ev_trig = {0};

  //  Event Trigger Condition ID
  //  Mandatory
  //  9.3.21
  msg_ev_trig.ev_trigger_cond_id = cond_id; // this parameter contains rnd value, but must be matched in ind hdr
  /* For each information change configured, Event Trigger Condition ID is assigned
  so that E2 Node can reply to Near-RT RIC in the RIC INDICATION message to inform
  which event(s) are the cause for triggering. */

  // CHOICE Trigger Type
  msg_ev_trig.msg_type = trigger_type;

  if (trigger_type == RRC_MSG_MSG_TYPE_EV_TRG) {
    msg_ev_trig.rrc_msg = fill_rrc_msg_id_3(class, msg_id);
  } else if (trigger_type == NETWORK_INTERFACE_MSG_TYPE_EV_TRG) {
    msg_ev_trig.net = fill_ni_msg_id_3(class);
  } else {
    assert(false && "Incorrect Trigger Type for Event Trigger Type 1!");
  }

  // Message Direction
  // Optional
  msg_ev_trig.msg_dir = NULL;

  // Associated UE Info
  // Optional
  // 9.3.26
  msg_ev_trig.assoc_ue_info = NULL;

  // Logical OR
  // Optional
  // 9.3.25
  msg_ev_trig.log_or = NULL;

  return msg_ev_trig;
}

static
rc_sub_data_t *gen_rc_sub_msg(const seq_report_sty_t *report_sty)
{
  assert(report_sty != NULL);

  rc_sub_data_t *rc_sub = calloc(1, sizeof(*rc_sub));
  assert(rc_sub != NULL && "Memory exhausted");

  if (cmp_str_ba("Message Copy", report_sty->name) == 0) {  // as defined in section 7.4.2, formats used for SUBSCRIPTION msg are known
    size_t const sz_1 = report_sty->sz_seq_ran_param;

    // Generate Event Trigger
    rc_sub->et.format = report_sty->ev_trig_type;
    assert(rc_sub->et.format == FORMAT_1_E2SM_RC_EV_TRIGGER_FORMAT && "Event Trigger Format received not valid");

    // Generate Action Definition
    rc_sub->sz_ad = 1;
    rc_sub->ad = calloc(rc_sub->sz_ad, sizeof(e2sm_rc_action_def_t));
    assert(rc_sub->ad != NULL && "Memory exhausted");
    rc_sub->ad[0].ric_style_type = 1; // REPORT Service Style 1: Message Copy
    rc_sub->ad[0].format = report_sty->act_frmt_type;
    assert(rc_sub->ad[0].format == FORMAT_1_E2SM_RC_ACT_DEF && "Action Definition Format received not valid");
    rc_sub->ad[0].frmt_1.sz_param_report_def = sz_1;
    rc_sub->ad[0].frmt_1.param_report_def = calloc(sz_1, sizeof(param_report_def_t));
    assert(rc_sub->ad[0].frmt_1.param_report_def != NULL && "Memory exhausted");

    // Fill Event Trigger
    const size_t msg_type_len = 5;
    rc_sub->et.frmt_1.sz_msg_ev_trg = msg_type_len;
    rc_sub->et.frmt_1.msg_ev_trg = calloc(msg_type_len, sizeof(msg_ev_trg_t));
    assert(rc_sub->et.frmt_1.msg_ev_trg != NULL && "Memory exhausted");

    // RRC Message copy
    rc_sub->et.frmt_1.msg_ev_trg[0] = fill_msg_ev_trig_3(RRC_MSG_MSG_TYPE_EV_TRG, 1, DL_DCCH_NR_RRC_CLASS, 1);  // rrcReconfiguration
    rc_sub->et.frmt_1.msg_ev_trg[1] = fill_msg_ev_trig_3(RRC_MSG_MSG_TYPE_EV_TRG, 2, UL_DCCH_NR_RRC_CLASS, 1);  // measurementReport
    rc_sub->et.frmt_1.msg_ev_trg[2] = fill_msg_ev_trig_3(RRC_MSG_MSG_TYPE_EV_TRG, 3, UL_DCCH_NR_RRC_CLASS, 6);  // securityModeComplete

    // UE ID
    rc_sub->et.frmt_1.msg_ev_trg[3] = fill_msg_ev_trig_3(RRC_MSG_MSG_TYPE_EV_TRG, 4, UL_DCCH_NR_RRC_CLASS, 3);  // rrcSetupComplete
    rc_sub->et.frmt_1.msg_ev_trg[4] = fill_msg_ev_trig_3(NETWORK_INTERFACE_MSG_TYPE_EV_TRG, 5, F1_NETWORK_INTERFACE_TYPE, 0);  // "F1 UE Context Setup Request", but cannot chose this specific msg; this way, any F1 msg will provide UE ID

    // Fill RAN Parameter Info
    for (size_t j = 0; j < sz_1; j++) {
      if (cmp_str_ba("RRC Message", report_sty->ran_param[j].name) != 0 && cmp_str_ba("UE ID", report_sty->ran_param[j].name) != 0) {
        printf("Received \"%s\" RAN Parameter ID. Expected \"RRC Message\" or \"UE ID\". No RIC SUBSCRIPTION sent.\n", report_sty->ran_param[j].name.buf);
        return NULL;
      }
      uint32_t const ran_param_id = report_sty->ran_param[j].id;
      ran_param_def_t const* ran_param_def = report_sty->ran_param[j].def;

      // Fill Action Definition
      rc_sub->ad[0].frmt_1.param_report_def[j] = fill_param_report(ran_param_id, ran_param_def);
    }      
  } else if (cmp_str_ba("UE Information", report_sty->name) == 0) {  // as defined in section 7.4.5, formats used for SUBSCRIPTION msg are known
    size_t const sz = report_sty->sz_seq_ran_param;

    // Generate Event Trigger
    rc_sub->et.format = report_sty->ev_trig_type;
    assert(rc_sub->et.format == FORMAT_4_E2SM_RC_EV_TRIGGER_FORMAT && "Event Trigger Format received not valid");
    rc_sub->et.frmt_4.sz_ue_info_chng = sz;
    rc_sub->et.frmt_4.ue_info_chng = calloc(sz, sizeof(ue_info_chng_t));
    assert(rc_sub->et.frmt_4.ue_info_chng != NULL && "Memory exhausted");

    // Generate Action Definition
    rc_sub->sz_ad = 1;
    rc_sub->ad = calloc(rc_sub->sz_ad, sizeof(e2sm_rc_action_def_t));
    assert(rc_sub->ad != NULL && "Memory exhausted");
    rc_sub->ad[0].ric_style_type = 4; // REPORT Service Style 4: UE Information
    rc_sub->ad[0].format = report_sty->act_frmt_type;
    assert(rc_sub->ad[0].format == FORMAT_1_E2SM_RC_ACT_DEF && "Action Definition Format received not valid");
    rc_sub->ad[0].frmt_1.sz_param_report_def = sz;
    rc_sub->ad[0].frmt_1.param_report_def = calloc(sz, sizeof(param_report_def_t));
    assert(rc_sub->ad[0].frmt_1.param_report_def != NULL && "Memory exhausted");

    // Fill RAN Parameter Info
    for (size_t j = 0; j < sz; j++) {
      if (cmp_str_ba("RRC State Changed To", report_sty->ran_param[j].name) != 0) {
        printf("Received \"%s\" RAN Parameter ID. Expected \"RRC State Changed To\". No RIC SUBSCRIPTION sent.\n", report_sty->ran_param[j].name.buf);
        return NULL;
      }

      ue_info_chng_trigger_type_e const trigger_type = RRC_STATE_UE_INFO_CHNG_TRIGGER_TYPE;
      uint32_t const ran_param_id = report_sty->ran_param[j].id;
      ran_param_def_t const* ran_param_def = report_sty->ran_param[j].def;
      // Fill Event Trigger
      rc_sub->et.frmt_4.ue_info_chng[j] = fill_ue_info_chng(trigger_type);
      // Fill Action Definition
      rc_sub->ad[0].frmt_1.param_report_def[j] = fill_param_report(ran_param_id, ran_param_def);
    }
  }

  return rc_sub;
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

static ran_func_def_report_t *get_rc_report_cap(const e2_node_connected_xapp_t *n, const int RC_ran_function)
{
  size_t const idx = find_sm_idx(n->rf, n->len_rf, eq_sm, RC_ran_function);
  if (n->rf[idx].defn.type != RC_RAN_FUNC_DEF_E) {
    printf("E2 node does not support RAN Control SM.\n");
    return NULL;
  }

  return n->rf[idx].defn.rc.report;
}

int main(int argc, char* argv[])
{
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

  // RAN Control REPORT handle
  sm_ans_xapp_t** hndl = (sm_ans_xapp_t**)calloc(nodes.len, sizeof(sm_ans_xapp_t*));
  assert(hndl != NULL);

  ////////////
  // START RC
  ////////////
  int const RC_ran_function = 3;

  for (int i = 0; i < nodes.len; i++) {
    e2_node_connected_xapp_t* n = &nodes.n[i];
    ran_func_def_report_t *rc_report = get_rc_report_cap(n, RC_ran_function);
    // if REPORT Service is supported by E2 node, send SUBSCRIPTION message
    if (rc_report != NULL) {
      // Generate RC SUBSCRIPTION messages
      const size_t sz_report_styles = rc_report->sz_seq_report_sty;
      hndl[i] = calloc(sz_report_styles, sizeof(sm_ans_xapp_t));
      assert(hndl[i] != NULL);

      for (size_t j = 0; j < sz_report_styles; j++) {
        rc_sub_data_t *rc_sub = gen_rc_sub_msg(&rc_report->seq_report_sty[j]);

        if (rc_sub) {
          hndl[i][j] = report_sm_xapp_api(&n->id, RC_ran_function, rc_sub, sm_cb_rc);
          assert(hndl[i][j].success == true);
          free_rc_sub_data(rc_sub);
          free(rc_sub);
        }
      }
    }
  }
  ////////////
  // END RC
  ////////////

  xapp_wait_end_api();

  for (int i = 0; i < nodes.len; i++) {
    // Remove the handle previously returned
    e2_node_connected_xapp_t* n = &nodes.n[i];
    ran_func_def_report_t *rc_report = get_rc_report_cap(n, RC_ran_function);
    if (rc_report != NULL) {
      for (size_t j = 0; j < rc_report->sz_seq_report_sty; j++) {
        if (hndl[i][j].success == true)
          rm_report_sm_xapp_api(hndl[i][j].u.handle);
      }
    }
    free(hndl[i]);
  }
  free(hndl);

  // Stop the xApp
  while (try_stop_xapp_api() == false)
    usleep(1000);

  printf("Test xApp run SUCCESSFULLY\n");
}
