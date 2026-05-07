/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */
 

#include "e42_xapp_api.h"
#include "e42_xapp.h"
#include "../util/conf_file.h"
#include "../lib/e2ap/e2ap_global_node_id_wrapper.h"
#include "../util/alg_ds/alg/defer.h"
#include "../util/alg_ds/alg/alg.h"
#include "../sm/slice_sm/slice_sm_id.h"
#include "../sm/tc_sm/tc_sm_id.h"
#include "../sm/rc_sm/rc_sm_id.h"
#include "../sm/mac_sm/mac_sm_id.h"

#include <signal.h>
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <limits.h>

static
e42_xapp_t* xapp = NULL;

static
pthread_t thrd_xapp;

static
atomic_bool stop_xapp = false;

static
void xapp_unblock_wait_api(void)
{
  stop_xapp = true;
}

void xapp_wait_end_api(void)
{
  const char* value = getenv("XAPP_DURATION");
  int timeout = value ? atoi(value) : 20;

  while (!stop_xapp && (timeout < 0 || timeout-- > 0))
    sleep(1);
}

static
void sig_handler(int sig_num)
{
  printf("\n[xApp]:Abruptly ending with signal number = %d\n", sig_num);

  xapp_unblock_wait_api();
}

static inline
void* static_start_xapp(void* a)
{
  (void)a;
  // Blocking...
  start_e42_xapp(xapp);
  return NULL;
}

void init_xapp_api(fr_args_t const* args)
{
  assert(xapp == NULL && "The init_xapp_api function can only be called once");
  assert(args != NULL);

  // Signal handler
  signal(SIGINT, sig_handler);
  signal(SIGTERM, sig_handler);

  xapp = init_e42_xapp(args);

  // Spawn a new thread for the xapp
  int rc = pthread_create(&thrd_xapp, NULL, static_start_xapp, NULL);
  assert(rc == 0);

  while(connected_e42_xapp(xapp) == false)
    sleep(1);
 
}
  
bool try_stop_xapp_api(void)
{
  assert(xapp != NULL);

  size_t sz = not_dispatch_msg(xapp);
  if(sz > 0) 
    return false;

  free_e42_xapp(xapp);

  int const rc = pthread_join(thrd_xapp, NULL);
  assert(rc == 0);
  printf("[xApp]: Successfully stopped \n");
  return true;
}

e2_node_arr_xapp_t e2_nodes_xapp_api(void)
{
  assert(xapp != NULL);
  
  return e2_nodes_xapp(xapp);
}

/*
static inline
bool valid_interval(inter_xapp_e i)
{
  assert(i == ms_1 
        || i == ms_1 
        || i == ms_2
        || i == ms_5
        || i == ms_10
        || i == ms_100
        || i == ms_1000
      );

  return true;
}
*/


static inline
bool valid_global_e2_node(global_e2_node_id_t* id, reg_e2_nodes_t* n)
{
  assert(id != NULL);
  assert(n != NULL);

  assoc_rb_tree_t t = cp_reg_e2_node(n); 
  defer({ assoc_free(&t); }; );

  void* it = assoc_front(&t);
  void* end = assoc_end(&t);

  it = find_if(&t, it, end, id, eq_global_e2_node_id_wrapper );

  return it == end ? false : true;
}

static inline
bool valid_sm_id(global_e2_node_id_t* id, uint32_t sm_id)
{
  assert(id != NULL);

  // Only for testing purposes
  assert( sm_id == 2 ||  sm_id == 3 ||  sm_id == 142 || sm_id == 143 || sm_id == 144 
      || sm_id == 145 || sm_id == 146 || sm_id == 147 || sm_id == 148);

  return true;
}

// returns a handle
sm_ans_xapp_t report_sm_xapp_api(global_e2_node_id_t* id, uint32_t rf_id, void* data, sm_cb handler)
{
  assert(xapp != NULL);
  assert(id != NULL);
  assert(data != NULL);

  assert(valid_global_e2_node(id, &xapp->e2_nodes) == true);
  assert(valid_sm_id(id, rf_id)  == true);

  return report_sm_sync_xapp(xapp, id, rf_id, data, handler);
}

// remove the handle previously returned
void rm_report_sm_xapp_api(int const handle)
{
  assert(xapp != NULL);
  assert(handle > -1);

  //printf("Remove handle number = %d \n", handle);
  rm_report_sm_sync_xapp(xapp, handle);
}

sm_ans_xapp_t control_sm_xapp_api(global_e2_node_id_t* id, uint32_t ran_func_id, void* wr)
{
  assert(xapp != NULL);
  assert(id != NULL);
  assert(ran_func_id == SM_MAC_ID || ran_func_id == SM_SLICE_ID || ran_func_id == SM_TC_ID || ran_func_id == SM_RC_ID);
  assert(wr != NULL);

  return control_sm_sync_xapp(xapp, id, ran_func_id, wr);
}


