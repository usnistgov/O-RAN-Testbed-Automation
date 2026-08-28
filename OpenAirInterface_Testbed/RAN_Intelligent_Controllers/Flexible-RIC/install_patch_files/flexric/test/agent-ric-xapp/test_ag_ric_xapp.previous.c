/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "../../src/agent/e2_agent_api.h"
#include "../../src/ric/near_ric_api.h"
#include "../../src/xApp/e42_xapp_api.h"
#include "../../src/sm/slice_sm/slice_sm_id.h"
#include "../../src/sm/gtp_sm/gtp_sm_id.h"
#include "../../src/sm/kpm_sm/kpm_sm_id_wrapper.h"
#include "../../src/sm/rc_sm/rc_sm_id.h" 
#include "../../src/util/alg_ds/alg/defer.h"
#include "../../src/util/time_now_us.h"

#include "../rnd/fill_rnd_data_gtp.h"                  
#include "../rnd/fill_rnd_data_tc.h"                  
#include "../rnd/fill_rnd_data_mac.h"                  
#include "../rnd/fill_rnd_data_rlc.h"                  
#include "../rnd/fill_rnd_data_pdcp.h"                  
#include "../rnd/fill_rnd_data_rc.h"                  
#include "../rnd/fill_rnd_data_tc.h"                  
#include "../rnd/fill_rnd_data_kpm.h"                  
#include "../rnd/fill_rnd_data_slice.h"                  
#include "../rnd/fill_rnd_data_e2_setup_req.h"                  

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>

static
void read_e2_setup_kpm(void* data)
{
  assert(data != NULL);
  //kpm_e2_setup_t* kpm = (kpm_e2_setup_t*)data;
}

static
void read_e2_setup_rc(void* data)
{
  assert(data != NULL);
  //rc_e2_setup_t* rc = (rc_e2_setup_t*)data;
}

#ifdef E2AP_V1
#elif defined(E2AP_V2) || defined(E2AP_V3)
static
void read_e2_setup_ran(void* data, const ngran_node_t node_type)
{
  assert(data != NULL);
  assert(node_type >=0 && node_type <= 10 && "Unknown E2 node type");
  
  arr_node_component_config_add_t* dst = (arr_node_component_config_add_t*)data;
  dst->len_cca = 1;
  dst->cca = calloc(1, sizeof(e2ap_node_component_config_add_t));
  assert(dst->cca != NULL);
  // NGAP
  dst->cca[0] = fill_ngap_e2ap_node_component_config_add();
}
#endif


static
bool read_ind_mac(void* ind)
{
  assert(ind != NULL);
  mac_ind_data_t* mac = (mac_ind_data_t*)ind;
  fill_mac_ind_data(mac);
  return true;
}

static
bool read_ind_rlc(void* ind)
{
  assert(ind != NULL);
  rlc_ind_data_t* rlc = (rlc_ind_data_t*)ind;
  fill_rlc_ind_data(rlc);
  return true;
}

static
bool read_ind_pdcp(void* ind)
{
  assert(ind != NULL);
  pdcp_ind_data_t* pdcp = (pdcp_ind_data_t*)ind;
  fill_pdcp_ind_data(pdcp);
  return true;
}

static
bool read_ind_slice(void* ind)
{
  assert(ind != NULL);
  slice_ind_data_t* slice = (slice_ind_data_t*)ind;
  fill_slice_ind_data(slice);
  return true;
}

static
bool read_ind_gtp(void* ind)
{
  assert(ind != NULL);
  gtp_ind_data_t* gtp = (gtp_ind_data_t*)ind;
  fill_gtp_ind_data(gtp);
  return true;
}

static
bool read_ind_tc(void* ind)
{
  assert(ind != NULL);
  tc_ind_data_t* tc = (tc_ind_data_t*)ind;
  fill_tc_ind_data(tc);
  return true;
}

static
bool read_ind_kpm(void* ind)
{
  assert(ind != NULL);
  kpm_ind_data_t* kpm = (kpm_ind_data_t*)ind;
  kpm->hdr = fill_rnd_kpm_ind_hdr();
  kpm->msg = fill_rnd_kpm_ind_msg();
  return true;
}

static
bool read_ind_rc(void* ind)
{
  assert(ind != NULL);
  assert(0!=0 && "The logic in RAN Ctrl SM for indication is different!"); 
  return true;
}

static
sm_ag_if_ans_t write_ctrl_slice(void const* data)
{
  assert(data != NULL);

  slice_ctrl_req_data_t const* slice_req_ctrl = (slice_ctrl_req_data_t const*)data;
  slice_ctrl_msg_t const* msg = &slice_req_ctrl->msg;

  if(msg->type == SLICE_CTRL_SM_V0_ADD){
    printf("[E2 Agent]: SLICE CONTROL ADD rx\n");
  } else if (msg->type == SLICE_CTRL_SM_V0_DEL){
    printf("[E2 Agent]: SLICE CONTROL DEL rx\n");
  } else if (msg->type == SLICE_CTRL_SM_V0_UE_SLICE_ASSOC){
    printf("[E2 Agent]: SLICE CONTROL ASSOC rx\n");
  } else {
    assert(0!=0 && "Unknown msg_type!");
  }

  sm_ag_if_ans_t ans = {.type =  CTRL_OUTCOME_SM_AG_IF_ANS_V0};
  ans.ctrl_out.type = SLICE_AGENT_IF_CTRL_ANS_V0;
  return ans;
}

static
sm_ag_if_ans_t write_ctrl_rc(void const* ctrl)
{
  assert(ctrl != NULL);
  
  rc_ctrl_req_data_t const* rc_ctrl = (rc_ctrl_req_data_t const*)ctrl;
  (void)rc_ctrl;

  printf("RAN_CONTROL_CTRL_V1_03 message called in the RAN \n");

  sm_ag_if_ans_t ans = {.type = CTRL_OUTCOME_SM_AG_IF_ANS_V0};
  ans.ctrl_out.type = RAN_CTRL_V1_3_AGENT_IF_CTRL_ANS_V0;
  ans.ctrl_out.rc = fill_rnd_rc_ctrl_out();
  return ans;
}

static
uint32_t sta_ric_id;

static
void free_aperiodic_subscription(uint32_t ric_req_id)
{
  assert(ric_req_id == sta_ric_id); 
  (void)ric_req_id;
}

static
void* emulate_rrc_msg(void* ptr)
{
  (void)ptr;
  for(size_t i = 0; i < 1000; ++i){
    usleep(rand()%50);
    rc_ind_data_t* d = calloc(1, sizeof(rc_ind_data_t)); 
    assert(d != NULL && "Memory exhausted");
    *d = fill_rnd_rc_ind_data();
    async_event_agent_api(sta_ric_id, d);
    printf("Event for RIC Req ID %u generated\n", sta_ric_id);
  }

  return NULL;
}

static
pthread_t t;

static
sm_ag_if_ans_t write_subs_rc(void const* data)
{
  assert(data != NULL);
  wr_rc_sub_data_t const* wr_rc = (wr_rc_sub_data_t const*)data; 

  sta_ric_id = wr_rc->ric_req_id;

  int rc = pthread_create(&t, NULL, emulate_rrc_msg, NULL);
  assert(rc == 0);

  sm_ag_if_ans_t ans = {.type = SUBS_OUTCOME_SM_AG_IF_ANS_V0};
  ans.subs_out.type = APERIODIC_SUBSCRIPTION_FLRC;
  ans.subs_out.aper.free_aper_subs = free_aperiodic_subscription;
  return ans;
}

static 
int cnt_mac = 0;
static
void sm_cb_mac(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == MAC_STATS_V0); 

  if(cnt_mac % 128 == 0){
    int64_t now = time_now_us();
    printf("MAC ind_msg latency = %ld μs\n", now - rd->ind.mac.msg.tstamp);
  }
  ++cnt_mac;
}

static 
int cnt_rlc = 0;
static
void sm_cb_rlc(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == RLC_STATS_V0); 

  if(cnt_rlc % 128 == 0){
  int64_t now = time_now_us();
  printf("RLC ind_msg latency = %ld μs\n", now - rd->ind.rlc.msg.tstamp);
  }
  ++cnt_rlc; 
}


static 
int cnt_gtp = 0;
static
void sm_cb_gtp(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == GTP_STATS_V0); 

  if(cnt_gtp % 128 == 0){
  int64_t now = time_now_us();
  printf("GTP ind_msg latency = %ld μs\n", now - rd->ind.gtp.msg.tstamp);
  }
  ++cnt_gtp;
}

static
void sm_cb_kpm(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == KPM_STATS_V3_0); 

  kpm_ind_data_t const* kpm = &rd->ind.kpm.ind;

  int64_t now = time_now_us();
  printf("KPM ind_msg latency = %ld μs\n", now - kpm->hdr.kpm_ric_ind_hdr_format_1.collectStartTime);
}

static
void sm_cb_rc(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == RAN_CTRL_STATS_V1_03); 

  rc_rd_ind_data_t const* rc = &rd->ind.rc;
  (void)rc;
  printf("RAN Control Indication data arrived\n");  
}


static
slice_ctrl_req_data_t create_add_slice(void)
{
  slice_ctrl_req_data_t ctrl_msg = {0}; 

  ctrl_msg.hdr.dummy = 2;
 
  slice_ctrl_msg_t* sl_ctrl_msg = &ctrl_msg.msg;
  sl_ctrl_msg->type = SLICE_CTRL_SM_V0_ADD;
  char sched_name[] = "My scheduler";
  size_t const sz = strlen(sched_name);
  sl_ctrl_msg->u.add_mod_slice.dl.len_sched_name = sz;
  sl_ctrl_msg->u.add_mod_slice.dl.sched_name = calloc(1,sz+1);
  memcpy(sl_ctrl_msg->u.add_mod_slice.dl.sched_name, sched_name, sz);

  sl_ctrl_msg->u.add_mod_slice.dl.len_slices = 1;
  sl_ctrl_msg->u.add_mod_slice.dl.slices = calloc(1, sizeof(fr_slice_t) );
  sl_ctrl_msg->u.add_mod_slice.dl.slices[0].id = 37;
  sl_ctrl_msg->u.add_mod_slice.dl.slices[0].params.type = SLICE_ALG_SM_V0_STATIC;
  sl_ctrl_msg->u.add_mod_slice.dl.slices[0].params.u.sta.pos_high = 10;
  sl_ctrl_msg->u.add_mod_slice.dl.slices[0].params.u.sta.pos_low = 0;
 
  return ctrl_msg; 
}

static
slice_ctrl_req_data_t create_assoc_slice(void)
{
  slice_ctrl_req_data_t ctrl_msg = {0}; 

  ctrl_msg.hdr.dummy = 2;
 
  slice_ctrl_msg_t* sl_ctrl_msg = &ctrl_msg.msg;
  sl_ctrl_msg->type = SLICE_CTRL_SM_V0_UE_SLICE_ASSOC;

  ue_slice_conf_t* ue_slice = &sl_ctrl_msg->u.ue_slice;

  ue_slice->len_ue_slice = 2;
  ue_slice->ues = calloc(2, sizeof(ue_slice_assoc_t));
  for(size_t i = 0; i < 2; ++i){
    ue_slice_assoc_t* assoc = &ue_slice->ues[i];
    assoc->dl_id = 42;
    assoc->ul_id = 42;
    assoc->rnti = 121;
  }

  return ctrl_msg;
}

static
sm_io_ag_ran_t init_sm_io_ag_ran(void)
{
  sm_io_ag_ran_t dst = {0};

  // READ: Indication
  dst.read_ind_tbl[MAC_STATS_V0 ] =  read_ind_mac;
  dst.read_ind_tbl[RLC_STATS_V0] =   read_ind_rlc;
  dst.read_ind_tbl[PDCP_STATS_V0] =   read_ind_pdcp;
  dst.read_ind_tbl[SLICE_STATS_V0] =   read_ind_slice;
  dst.read_ind_tbl[TC_STATS_V0] =   read_ind_tc;
  dst.read_ind_tbl[GTP_STATS_V0] =   read_ind_gtp;
  dst.read_ind_tbl[KPM_STATS_V3_0] =   read_ind_kpm;
  dst.read_ind_tbl[RAN_CTRL_STATS_V1_03] = read_ind_rc;

  //  READ: E2 Setup
  dst.read_setup_tbl[KPM_V3_0_AGENT_IF_E2_SETUP_ANS_V0] = read_e2_setup_kpm;
  dst.read_setup_tbl[RAN_CTRL_V1_3_AGENT_IF_E2_SETUP_ANS_V0] = read_e2_setup_rc;

  //  READ: E2 Setup RAN
#if defined(E2AP_V2) || defined(E2AP_V3)
  dst.read_setup_ran = read_e2_setup_ran;
#endif

  // WRITE: CONTROL
  dst.write_ctrl_tbl[SLICE_CTRL_REQ_V0] = write_ctrl_slice;
  dst.write_ctrl_tbl[RAN_CONTROL_CTRL_V1_03] = write_ctrl_rc;

  // WRITE: SUBSCRIPTION
  dst.write_subs_tbl[RAN_CTRL_SUBS_V1_03] = write_subs_rc; 

  return dst;
}






int main(int argc, char *argv[])
{
  // Init the Agent
  const int mcc = 208; 
  const int mnc = 92; 
  const int mnc_digit_len = 2;
  const int nb_id = 42;
  const int cu_du_id = 0;
  ngran_node_t ran_type = ngran_gNB;
  sm_io_ag_ran_t io = init_sm_io_ag_ran(); // {.read = read_RAN, .write = write_RAN};

  fr_args_t args = init_fr_args(argc, argv);  // Parse arguments
  
  // Init the RIC
  init_near_ric_api(&args);

  init_agent_api(mcc, mnc, mnc_digit_len, nb_id, cu_du_id, ran_type, io, &args);
  sleep(1);

  //Init the xApp
  init_xapp_api(&args);

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  defer({ free_e2_node_arr_xapp(&nodes); });

  assert(nodes.len > 0);

  printf("Connected E2 nodes = %d\n", nodes.len );

  e2_node_connected_xapp_t* n = &nodes.n[0];
  for(size_t i = 0; i < n->len_rf; ++i)
    printf("Registered ran func id = %d \n ", n->rf[i].id );

  const char* period = "5_ms";
  // returns a handle
  sm_ans_xapp_t h_1 = report_sm_xapp_api(&nodes.n[0].id, 142, (void*)period, sm_cb_mac);
  assert(h_1.success == true);

  // returns a handle
  sm_ans_xapp_t h_2 = report_sm_xapp_api(&nodes.n[0].id, 143, (void*)period, sm_cb_rlc);
  assert(h_2.success == true);

  // returns a handle
  sm_ans_xapp_t h_3 = report_sm_xapp_api(&nodes.n[0].id, SM_GTP_ID, (void*)period, sm_cb_gtp);
  assert(h_3.success == true);

  // Control ADD slice
  slice_ctrl_req_data_t ctrl_msg_add = create_add_slice();
 
  control_sm_xapp_api(&nodes.n[0].id, SM_SLICE_ID, &ctrl_msg_add);
  free(ctrl_msg_add.msg.u.add_mod_slice.dl.slices); 
  free(ctrl_msg_add.msg.u.add_mod_slice.dl.sched_name);


  // Control ASSOC slice
  slice_ctrl_req_data_t ctrl_msg_assoc = create_assoc_slice();
  control_sm_xapp_api(&nodes.n[0].id, SM_SLICE_ID, &ctrl_msg_assoc);
  free(ctrl_msg_assoc.msg.u.ue_slice.ues); 

  // KPM 
  kpm_sub_data_t kpm_sub = {0};
  kpm_sub.ev_trg_def = fill_rnd_kpm_event_trigger_def();
  kpm_sub.sz_ad = 1; 
  kpm_sub.ad = calloc(1, sizeof(kpm_act_def_t));
  assert(kpm_sub.ad != NULL && "Memory exhausted");
  kpm_sub.ad[0] = fill_rnd_kpm_action_def();
  defer({ free_kpm_sub_data(&kpm_sub); });

  sm_ans_xapp_t h_4 = report_sm_xapp_api(&nodes.n[0].id, SM_KPM_ID, &kpm_sub, sm_cb_kpm);
  assert(h_4.success == true);

  // RC Control 
  rc_ctrl_req_data_t rc_ctrl = fill_rc_ctrl();
  control_sm_xapp_api(&nodes.n[0].id, SM_RC_ID, &rc_ctrl);
  free_rc_ctrl_req_data(&rc_ctrl);
  
  // RC Subscription 
  rc_sub_data_t rc_sub = {0};
  defer({ free_rc_sub_data(&rc_sub); });

  rc_sub.et = fill_rnd_rc_event_trigger();

 // [1-16]
  rc_sub.sz_ad = 1;
  rc_sub.ad = calloc(rc_sub.sz_ad, sizeof(e2sm_rc_action_def_t));
  assert(rc_sub.ad != NULL && "Memory exhausted");
  rc_sub.ad[0] = fill_rnd_rc_action_def();

  sm_ans_xapp_t h_5 = report_sm_xapp_api(&nodes.n[0].id, SM_RC_ID, &rc_sub, sm_cb_rc);
  assert(h_5.success);

  sleep(3);
  
  rm_report_sm_xapp_api(h_1.u.handle);
  rm_report_sm_xapp_api(h_2.u.handle);
  rm_report_sm_xapp_api(h_3.u.handle);
  rm_report_sm_xapp_api(h_4.u.handle);
  rm_report_sm_xapp_api(h_5.u.handle);

  sleep(1);

  //Stop the xApp
  while(try_stop_xapp_api() == false)
    usleep(1000);     

  // Stop the Agent
  stop_agent_api();

  // Stop the RIC
  stop_near_ric_api();

  int const rc = pthread_join(t, NULL);
  assert(rc == 0);

  printf("Test communicating E2-Agent, Near-RIC and xApp run SUCCESSFULLY\n");
}

