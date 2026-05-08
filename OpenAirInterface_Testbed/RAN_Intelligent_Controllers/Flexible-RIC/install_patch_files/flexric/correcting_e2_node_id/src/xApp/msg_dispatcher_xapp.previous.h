/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */



#ifndef MESSAGE_DISPATCHER_XAPP_H
#define MESSAGE_DISPATCHER_XAPP_H 


#include "../util/alg_ds/ds/tsn_queue/tsn_queue.h"
#include "../sm/agent_if/read/sm_ag_if_rd.h"

#include <pthread.h>


typedef struct{
  pthread_t p;
  tsnq_t q;
} msg_dispatcher_xapp_t;

typedef struct{
  sm_ag_if_rd_t rd; 
  void (*sm_cb)(sm_ag_if_rd_t const*);
} msg_dispatch_t ;

void init_msg_dispatcher( msg_dispatcher_xapp_t* d);

void free_msg_dispatcher( msg_dispatcher_xapp_t* d);

void send_msg_dispatcher( msg_dispatcher_xapp_t* d, msg_dispatch_t* msg );

size_t size_msg_dispatcher(msg_dispatcher_xapp_t* d);

#endif

