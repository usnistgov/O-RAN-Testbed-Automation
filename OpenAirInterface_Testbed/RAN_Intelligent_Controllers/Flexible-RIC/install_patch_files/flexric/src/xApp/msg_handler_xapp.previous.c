/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */


#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

#include "act_proc.h"
#include "endpoint_xapp.h"
#include "msg_handler_xapp.h"
#include "util/alg_ds/alg/alg.h"
#include "util/alg_ds/ds/lock_guard/lock_guard.h"
#include "util/compare.h"

#include "msg_generator_xapp.h"
#include "e2ap_xapp.h"

#include "lib/e2ap/e2ap_msg_free_wrapper.h"
#include "lib/pending_events.h"

#include "../sm/rlc_sm/rlc_sm_id.h"

static inline
bool check_valid_msg_type(e2_msg_type_t msg_type)
{
  if(msg_type == RIC_SUBSCRIPTION_RESPONSE ||
      msg_type == RIC_SUBSCRIPTION_FAILURE ||
      msg_type == RIC_SUBSCRIPTION_DELETE_RESPONSE ||
      msg_type == RIC_SUBSCRIPTION_DELETE_FAILURE ||
      msg_type == RIC_INDICATION ||
      msg_type == RIC_CONTROL_ACKNOWLEDGE ||
      msg_type == RIC_CONTROL_FAILURE ||
      msg_type == E2AP_ERROR_INDICATION ||

      msg_type == E42_SETUP_RESPONSE ||
      msg_type == E2_SETUP_FAILURE ||
 
      msg_type == E42_RIC_CONTROL_REQUEST || 

      msg_type == E42_SETUP_REQUEST ||

      msg_type == E2AP_RESET_REQUEST ||
      msg_type == E2AP_RESET_RESPONSE ||
      msg_type == RIC_SERVICE_UPDATE ||
      msg_type == E2_NODE_CONFIGURATION_UPDATE ||
      msg_type == E2_CONNECTION_UPDATE_ACKNOWLEDGE ||
      msg_type == E2_CONNECTION_UPDATE_FAILURE )
    return true;

  return false;
}


static
void add_pending_event_xapp(e42_xapp_t* xapp, pending_event_xapp_t* ev)
{
  assert(xapp != NULL);
  assert(ev != NULL);
  assert(ev->wait_ms > 0);

  int fd_timer = create_timer_ms_asio_xapp(&xapp->io, ev->wait_ms, ev->wait_ms); 
  add_pending_event(&xapp->pending, fd_timer, ev);
}

static
void rm_pending_event_xapp(e42_xapp_t* xapp, pending_event_xapp_t* ev)
{
  int* fd = rm_pending_event_ev(&xapp->pending, ev);
  rm_fd_asio_xapp(&xapp->io, *fd);
  defer({ free(fd); } );
}

void init_handle_msg_xapp(size_t len, e2ap_handle_msg_fp_xapp (*handle_msg)[len])
{
  assert(len == NONE_E2_MSG_TYPE);
  memset((*handle_msg), 0, sizeof(e2ap_handle_msg_fp_xapp)*len);
  (*handle_msg)[RIC_SUBSCRIPTION_RESPONSE] = e2ap_handle_subscription_response_xapp;
  (*handle_msg)[RIC_SUBSCRIPTION_FAILURE] = e2ap_handle_subscription_failure_xapp;
  (*handle_msg)[RIC_SUBSCRIPTION_DELETE_RESPONSE] = e2ap_handle_subscription_delete_response_xapp;
  (*handle_msg)[RIC_SUBSCRIPTION_DELETE_FAILURE] = e2ap_handle_subscription_delete_failure_xapp;
  (*handle_msg)[RIC_INDICATION] = e2ap_handle_indication_xapp;
  (*handle_msg)[RIC_CONTROL_ACKNOWLEDGE] = e2ap_handle_control_ack_xapp;
  (*handle_msg)[RIC_CONTROL_FAILURE] = e2ap_handle_control_failure_xapp;
  (*handle_msg)[E2AP_ERROR_INDICATION] = e2ap_handle_error_indication_xapp;

  // Different from RIC 
  (*handle_msg)[E42_SETUP_REQUEST] = e2ap_handle_e42_setup_request_xapp;
  (*handle_msg)[E42_SETUP_RESPONSE] = e2ap_handle_e42_setup_response_xapp;
  (*handle_msg)[E2_SETUP_FAILURE] = e2ap_handle_setup_failure_xapp;

  (*handle_msg)[E42_RIC_SUBSCRIPTION_REQUEST] = e2ap_handle_e42_ric_subscription_request_xapp;
//  (*handle_msg)[RIC_SUBSCRIPTION_DELETE_REQUEST] = e2ap_handle_subscription_delete_request_xapp;
  (*handle_msg)[E42_RIC_SUBSCRIPTION_DELETE_REQUEST] = e2ap_handle_e42_subscription_delete_request_xapp;

  (*handle_msg)[E42_RIC_CONTROL_REQUEST] = e2ap_handle_e42_ric_control_request_xapp;

  (*handle_msg)[E2AP_RESET_REQUEST] = e2ap_handle_reset_request_xapp;
  (*handle_msg)[E2AP_RESET_RESPONSE] = e2ap_handle_reset_response_xapp;
  (*handle_msg)[RIC_SERVICE_UPDATE] = e2ap_handle_service_update_xapp;
  (*handle_msg)[E2_NODE_CONFIGURATION_UPDATE] = e2ap_handle_node_configuration_update_xapp;
  (*handle_msg)[E2_CONNECTION_UPDATE_ACKNOWLEDGE] = e2ap_handle_connection_update_ack_xapp;
  (*handle_msg)[E2_CONNECTION_UPDATE_FAILURE] = e2ap_handle_connection_update_failure_xapp;
}

e2ap_msg_t e2ap_msg_handle_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  const e2_msg_type_t msg_type = msg->type;
  assert(check_valid_msg_type(msg_type) == true);
  assert(xapp->handle_msg[ msg_type ] != NULL);
  return xapp->handle_msg[msg_type](xapp, msg);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// O-RAN E2APv01.01: Messages for Global Procedures ///////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

// E2 -> RIC 
 e2ap_msg_t e2ap_handle_subscription_response_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_SUBSCRIPTION_RESPONSE);

  ric_subscription_response_t const* resp = &msg->u_msgs.ric_sub_resp;

  act_proc_ans_t rv = find_act_proc(&xapp->act_proc, resp->ric_id.ric_req_id);
  assert(rv.ok == true && "ric_req_id not registered in the registry");

  printf("[xApp]: SUBSCRIPTION RESPONSE rx\n");

  pending_event_xapp_t ev = {.ev = E42_RIC_SUBSCRIPTION_REQUEST_PENDING_EVENT,
                             .id = rv.val.id};
  // Remove pending event  
  rm_pending_event_xapp(xapp, &ev);

  // Unblock UI thread  
  signal_sync_ui(&xapp->sync);

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// E2 -> RIC 
 e2ap_msg_t e2ap_handle_subscription_failure_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_SUBSCRIPTION_FAILURE);
  assert(0!=0 && "Not implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_subscription_delete_response_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_SUBSCRIPTION_DELETE_RESPONSE);

  ric_subscription_delete_response_t const* resp = &msg->u_msgs.ric_sub_del_resp;

  act_proc_ans_t rv = find_act_proc(&xapp->act_proc, resp->ric_id.ric_req_id);
  assert(rv.ok == true && "ric_req_id not registered in the registry");

  printf("[xApp]: E42 SUBSCRIPTION DELETE RESPONSE rx\n");

  pending_event_xapp_t ev = {.ev = E42_RIC_SUBSCRIPTION_DELETE_REQUEST_PENDING_EVENT, .id = rv.val.id };

  // Stop the timer
  rm_pending_event_xapp(xapp, &ev);

  // Unblock UI thread  
  signal_sync_ui(&xapp->sync);

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

//E2 -> RIC
 e2ap_msg_t e2ap_handle_subscription_delete_failure_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_SUBSCRIPTION_DELETE_FAILURE);
  assert(0!=0 && "Not implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE };
  return ans;
}

static
sm_ind_data_t ind_sm_payload(ric_indication_t const* src)
{
  assert(src != NULL);
  sm_ind_data_t ind_data = {  .ind_hdr = src->hdr.buf,
                              .len_hdr = src->hdr.len,
                              .ind_msg = src->msg.buf, 
                              .len_msg = src->msg.len, 
                           };

  if(src->call_process_id != NULL){
    assert(src->call_process_id->len > 0); 
    ind_data.len_cpid = src->call_process_id->len;
    ind_data.call_process_id = malloc(src->call_process_id->len );
    assert(ind_data.call_process_id != NULL);
    memcpy(ind_data.call_process_id, src->call_process_id->buf, src->call_process_id->len);
  }
  return ind_data;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_indication_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_INDICATION);

  ric_indication_t const* src = &msg->u_msgs.ric_ind;

  const uint16_t ran_func_id = src->ric_id.ran_func_id;  

  //printf("[xApp]: RIC_INDICATION RAN_FUNC_ID = %d\n", ran_func_id );

  sm_ric_t* sm = sm_plugin_ric(&xapp->plugin_ric ,ran_func_id);

  sm_ind_data_t ind_data = ind_sm_payload(src);

  msg_dispatch_t msg_disp = {.rd.type = INDICATION_MSG_AGENT_IF_ANS_V0 };
  msg_disp.rd.ind = sm->proc.on_indication(sm, &ind_data);
  assert(msg_disp.rd.ind.type == MAC_STATS_V0 || msg_disp.rd.ind.type == RLC_STATS_V0 
      || msg_disp.rd.ind.type == PDCP_STATS_V0 || msg_disp.rd.ind.type == SLICE_STATS_V0 
      || msg_disp.rd.ind.type == KPM_STATS_V3_0 || msg_disp.rd.ind.type == GTP_STATS_V0
      || msg_disp.rd.ind.type == RAN_CTRL_STATS_V1_03);
  
  act_proc_ans_t ans = find_act_proc(&xapp->act_proc, src->ric_id.ric_req_id);

  if(ans.ok == false){
    printf("%s \n", ans.error); 
    printf("ric_req_id = %d not in the registry. Spuriosly can happen.\n",  src->ric_id.ric_req_id);
    free_sm_ag_if_rd(&msg_disp.rd);
  } else {
   
   // Write to SQL DB
   write_db_xapp(&xapp->db, &ans.val.e2_node, &msg_disp.rd);

    // Write to the callback. Should I send the E2 Node info to the cb??
    msg_disp.sm_cb = ans.val.sm_cb;
    send_msg_dispatcher(&xapp->msg_disp, &msg_disp );
 }

  e2ap_msg_t ret = {.type = NONE_E2_MSG_TYPE };
  return ret;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_control_ack_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_CONTROL_ACKNOWLEDGE);

  ric_control_acknowledge_t const* ack = &msg->u_msgs.ric_ctrl_ack;
#ifdef E2AP_V1 
  assert( ack->status == RIC_CONTROL_STATUS_SUCCESS && "Only success supported ") ;
#endif
  act_proc_ans_t rv = find_act_proc(&xapp->act_proc, ack->ric_id.ric_req_id);
  assert(rv.ok == true && "ric_req_id not registered in the registry");

  printf("[xApp]: CONTROL ACK rx\n");

  // A pending event is created along with a timer of 5000 ms,
  // after which an event will be generated
  pending_event_xapp_t ev = {.ev = E42_RIC_CONTROL_REQUEST_PENDING_EVENT, .id = rv.val.id };

  // Stop the timer
  rm_pending_event_xapp(xapp, &ev);

  // Unblock UI thread  
  signal_sync_ui(&xapp->sync);

  // If the answer of control_ack is needed 
  // use the field ack->control_outcome 

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_control_failure_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_CONTROL_FAILURE);

  ric_control_failure_t const* failure = &msg->u_msgs.ric_ctrl_fail;
  act_proc_ans_t rv = find_act_proc(&xapp->act_proc, failure->ric_id.ric_req_id);
  assert(rv.ok == true && "ric_req_id not registered in the registry");

  printf("[xApp]: CONTROL FAILURE rx\n");

  // A pending event is created along with a timer of 5000 ms,
  // after which an event will be generated
  pending_event_xapp_t ev = {.ev = E42_RIC_CONTROL_REQUEST_PENDING_EVENT, .id = rv.val.id };

  // Stop the timer
  rm_pending_event_xapp(xapp, &ev);

  // Unblock UI thread
  signal_sync_ui(&xapp->sync);

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}
  
///////////////////////////////////////////////////////////////////////////////////////////////////
// O-RAN E2APv01.01: Messages for Global Procedures ///////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

e2ap_msg_t e2ap_handle_setup_response_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);

  assert(0!=0 && "Unknwonw data path, E2 Setup response not foreseen at the xApp, but rather E42");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans; 
}

static inline
void send_setup_request(e42_xapp_t* xapp)
{
  assert(xapp != NULL);
  assert(xapp->handle_msg[E42_SETUP_REQUEST]!= NULL);
  xapp->handle_msg[E42_SETUP_REQUEST](xapp, NULL);
}

e2ap_msg_t e2ap_handle_e42_setup_response_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E42_SETUP_RESPONSE);

  lock_guard(&xapp->conn_mtx);

  if(xapp->connected == true){
    e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
    return ans; 
  }
  assert(xapp->connected == false);

  e42_setup_response_t const* sr = &msg->u_msgs.e42_stp_resp;

  printf("[xApp]: E42 SETUP-RESPONSE rx \n");

  *(uint16_t*)&xapp->id = sr->xapp_id;
  printf("[xApp]: xApp ID = %u \n", sr->xapp_id);

  for(size_t i = 0; i < sr->len_e2_nodes_conn; ++i){
    global_e2_node_id_t const* id = &sr->nodes[i].id;
    const size_t len = sr->nodes[i].len_rf;
    ran_function_t* rf = sr->nodes[i].ack_rf; 
#ifdef E2AP_V1
    add_reg_e2_node_v1(&xapp->e2_nodes, id, len, rf);
#elif defined(E2AP_V2) || defined(E2AP_V3)
    add_reg_e2_node(&xapp->e2_nodes, id, len, rf, sr->nodes[i].len_cca, sr->nodes[i].cca);
#else
    static_assert(0 !=0, "Unknown E2AP version");
#endif

  }

  // Stop the timer
  pending_event_xapp_t ev = {.ev = E42_SETUP_REQUEST_PENDING_EVENT };
  rm_pending_event_xapp(xapp, &ev);

  if (sz_reg_e2_node(&xapp->e2_nodes) == 0) {
    printf("[xApp]: The nearRT-RIC has no registered nodes. Resending the E42 SETUP-REQUEST in 5s.\n");
    sleep(5);
    send_setup_request(xapp);
    xapp->connected = false;
  } else {
    xapp->connected = true;
  }

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans; 
}

e2ap_msg_t e2ap_handle_setup_failure_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(0!=0 && "Not implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans; 
}

// RIC <-> E2 
 e2ap_msg_t e2ap_handle_error_indication_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E2AP_ERROR_INDICATION);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// RIC <-> E2
 e2ap_msg_t e2ap_handle_reset_request_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E2AP_RESET_REQUEST);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// RIC <-> E2
 e2ap_msg_t e2ap_handle_reset_response_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E2AP_RESET_RESPONSE);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}
  
// E2 -> RIC
 e2ap_msg_t e2ap_handle_service_update_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == RIC_SERVICE_UPDATE);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_node_configuration_update_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E2_NODE_CONFIGURATION_UPDATE);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {0};
  return ans;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_connection_update_ack_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E2_CONNECTION_UPDATE_ACKNOWLEDGE);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// E2 -> RIC
 e2ap_msg_t e2ap_handle_connection_update_failure_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E2_CONNECTION_UPDATE_FAILURE);
  assert(0 != 0 && "Not Implemented");

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

// xApp -> iApp
e2ap_msg_t e2ap_handle_e42_setup_request_xapp(struct e42_xapp_s* xapp, const struct e2ap_msg_s* msg)
{
  assert(xapp != NULL);
  assert(msg == NULL && "Not accepting any msg");

  e42_setup_request_t sr = generate_e42_setup_request(xapp); 
  defer({ e2ap_free_e42_setup_request(&sr);  } );

  assert(sr.len_rf > 0);
  assert(sr.ran_func_item != NULL);

  byte_array_t ba = e2ap_enc_e42_setup_request_xapp(&xapp->ap, &sr); 
  defer({free_byte_array(ba); } ); 

  e2ap_send_bytes_xapp(&xapp->ep, ba);

  printf("[xApp]: E42 SETUP-REQUEST tx\n");

  // A pending event is created along with a timer of 1000 ms,
  // after which an event will be triggered
  pending_event_xapp_t x_ev = {.ev = E42_SETUP_REQUEST_PENDING_EVENT,
                                .wait_ms = 1000,
                               .id = {0} }; 
  add_pending_event_xapp(xapp, &x_ev);

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE };
  return ans;
}

e2ap_msg_t e2ap_handle_e42_ric_subscription_request_xapp(struct e42_xapp_s* xapp, const struct e2ap_msg_s* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E42_RIC_SUBSCRIPTION_REQUEST);

  e42_ric_subscription_request_t const* e42_sr = &msg->u_msgs.e42_ric_sub_req; 

  byte_array_t ba_msg = e2ap_enc_e42_subscription_request_xapp(&xapp->ap,(e42_ric_subscription_request_t*)e42_sr);
  defer({ free_byte_array(ba_msg) ;}; );

  // A pending event is created along with a timer of 5000 ms,
  // after which an event will be triggered. The answer needs to arrive before 
  // the timer expires
  pending_event_xapp_t ev = {.ev = E42_RIC_SUBSCRIPTION_REQUEST_PENDING_EVENT, 
                              .id = e42_sr->sr.ric_id,
                              .wait_ms = 5000};
  add_pending_event_xapp(xapp, &ev);


  e2ap_send_bytes_xapp(&xapp->ep, ba_msg);

  printf("[xApp]: E42 RIC SUBSCRIPTION REQUEST tx RAN_FUNC_ID %d RIC_REQ_ID %d \n",e42_sr->sr.ric_id.ran_func_id, e42_sr->sr.ric_id.ric_req_id );

  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

 

e2ap_msg_t e2ap_handle_e42_subscription_delete_request_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E42_RIC_SUBSCRIPTION_DELETE_REQUEST);

  const e42_ric_subscription_delete_request_t* e42_sdr = &msg->u_msgs.e42_ric_sub_del_req;
  printf("[xApp]: E42 RIC_SUBSCRIPTION_DELETE_REQUEST tx RAN_FUNC_ID %d RIC_REQ_ID %d \n", e42_sdr->sdr.ric_id.ran_func_id, e42_sdr->sdr.ric_id.ric_req_id);

  byte_array_t ba_msg = e2ap_enc_e42_ric_subscription_delete_xapp(&xapp->ap,( e42_ric_subscription_delete_request_t* ) e42_sdr);
  defer({ free_byte_array(ba_msg) ;}; );

  e2ap_send_bytes_xapp(&xapp->ep, ba_msg);

  // A pending event is created along with a timer of 10000 ms,
  // after which an event will be generated
  pending_event_xapp_t ev = {.ev = E42_RIC_SUBSCRIPTION_DELETE_REQUEST_PENDING_EVENT, 
                              .id = e42_sdr->sdr.ric_id,
                              .wait_ms = 10000};
  add_pending_event_xapp(xapp, &ev);


  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans; 
}

e2ap_msg_t e2ap_handle_e42_ric_control_request_xapp(e42_xapp_t* xapp, const e2ap_msg_t* msg)
{
  assert(xapp != NULL);
  assert(msg != NULL);
  assert(msg->type == E42_RIC_CONTROL_REQUEST);

  const e42_ric_control_request_t* cr = &msg->u_msgs.e42_ric_ctrl_req;

  byte_array_t ba_msg = e2ap_enc_e42_control_request_xapp(&xapp->ap,(  e42_ric_control_request_t* ) cr);
  defer({ free_byte_array(ba_msg) ;}; );

  e2ap_send_bytes_xapp(&xapp->ep, ba_msg);

  printf("[xApp]: CONTROL-REQUEST tx \n");

  pending_event_xapp_t ev = {.ev = E42_RIC_CONTROL_REQUEST_PENDING_EVENT,
    .id = cr->ctrl_req.ric_id,
    .wait_ms = 10000};
  add_pending_event_xapp(xapp, &ev);


  e2ap_msg_t ans = {.type = NONE_E2_MSG_TYPE};
  return ans;
}

