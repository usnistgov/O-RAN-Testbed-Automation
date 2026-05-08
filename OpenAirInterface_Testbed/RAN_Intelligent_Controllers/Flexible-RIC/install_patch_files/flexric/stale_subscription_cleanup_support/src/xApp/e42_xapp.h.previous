/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#ifndef E42_XAPP_H
#define E42_XAPP_H 

// RIC but it needs to start the setup request

#include "asio_xapp.h"
#include "e2ap_xapp.h"
#include "endpoint_xapp.h"
#include "msg_dispatcher_xapp.h"
#include "util/alg_ds/ds/seq_container/seq_generic.h"
#include "util/alg_ds/ds/assoc_container/assoc_generic.h"
#include "util/alg_ds/ds/assoc_container/bimap.h"
#include "util/alg_ds/ds/tsn_queue/tsn_queue.h"

#include "../lib/msg_hand/reg_e2_nodes.h"
#include "db/db.h"
#include "e42_xapp_api.h"
#include "pending_event_xapp.h"

#include "act_proc.h"
#include "plugin_agent.h"
#include "plugin_ric.h"
#include "sync_ui.h"

#include <stdatomic.h>

#ifdef E2AP_V1
#define HANDLE_MSG_NUM 31
#elif  E2AP_V2
#define HANDLE_MSG_NUM 34
#elif  E2AP_V3
#define HANDLE_MSG_NUM 43
#else
static_assert(0!=0 , "Not implemented");
#endif

typedef struct e42_xapp_s e42_xapp_t;

typedef struct e2ap_msg_s (*e2ap_handle_msg_fp_xapp)(struct e42_xapp_s* xapp, const struct e2ap_msg_s* msg);

typedef struct e42_xapp_s
{
  e2ap_ep_xapp_t ep;
  e2ap_xapp_t ap; 
  asio_xapp_t io;

  size_t sz_handle_msg;
  e2ap_handle_msg_fp_xapp handle_msg[HANDLE_MSG_NUM ]; // note that not all the slots will be occupied

  // Registered SMs
  plugin_ag_t plugin_ag; // Needed for E2 setup request
  plugin_ric_t plugin_ric; // Needed for Subscription, Control, etc ...

  // Connected E2 Nodes, key: global_e2_node_id | value: seq_arr_t of ran_function_t 
  reg_e2_nodes_t e2_nodes; 

  // xApp ID, used for uniquely identify the xApp at the iApp 
  const uint16_t id;

  // Syncronization primitives
   sync_ui_t sync;

  // Active Procedures. 
  // It provides a monotonically increasing RIC request ID
  // as well as it stores the ric_gen_id_t and the callbacks
  act_proc_t act_proc;   
  
  // Pending events (i.e., waiting response)
  pending_event_xapp_ds_t pending;

  // Indication Messages dispatcher
  msg_dispatcher_xapp_t msg_disp; 

  // DB handler
  db_xapp_t db;

  pthread_mutex_t conn_mtx;
  atomic_bool connected;
  atomic_bool stopped;
  atomic_bool stop_token;
} e42_xapp_t;

e42_xapp_t* init_e42_xapp(fr_args_t const* args);

bool connected_e42_xapp( e42_xapp_t* xapp);

// Blocking call
void start_e42_xapp(e42_xapp_t* xapp);

void free_e42_xapp(e42_xapp_t* xapp);

e2_node_arr_xapp_t e2_nodes_xapp(e42_xapp_t* xapp);

size_t not_dispatch_msg(e42_xapp_t* xapp);

// We wait for the message to come back and avoid asyncronous programming
sm_ans_xapp_t report_sm_sync_xapp(e42_xapp_t* xapp, global_e2_node_id_t* id, uint16_t ran_func_id, void* data, sm_cb cb);

// We wait for the message to come back and avoid asyncronous programming
void rm_report_sm_sync_xapp(e42_xapp_t* xapp, int handle);

// We wait for the message to come back and avoid asyncronous programming
sm_ans_xapp_t control_sm_sync_xapp(e42_xapp_t* xapp, global_e2_node_id_t* id, uint16_t ran_func_id, void* ctrl_msg);

#undef HANDLE_MSG_NUM 

#endif

