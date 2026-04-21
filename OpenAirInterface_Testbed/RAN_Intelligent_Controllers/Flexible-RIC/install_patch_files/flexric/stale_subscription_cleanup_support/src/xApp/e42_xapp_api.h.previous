/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */
  
#ifndef E42_XAPP_API_H
#define E42_XAPP_API_H 

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

#include "e2_node_arr_xapp.h"
#include "../sm/agent_if/write/sm_ag_if_wr.h"
#include "../sm/agent_if/read/sm_ag_if_rd.h"
#include "../util/conf_file.h"

void xapp_wait_end_api(void);

void init_xapp_api(fr_args_t const*);
  
bool try_stop_xapp_api(void);     

e2_node_arr_xapp_t e2_nodes_xapp_api(void);

typedef void (*sm_cb)(sm_ag_if_rd_t const*);

typedef union{
  char* reason;
  int handle;
} sm_ans_xapp_u;

typedef struct{
  sm_ans_xapp_u u;
  bool success;
} sm_ans_xapp_t;

typedef enum{
  ms_1,
  ms_2,
  ms_5,
  ms_10,
  ms_100,
  ms_1000,

  ms_end,
} inter_xapp_e;

// Returns a handle
sm_ans_xapp_t report_sm_xapp_api(global_e2_node_id_t* id, uint32_t rf_id, void* data, sm_cb handler);

// Remove the handle previously returned
void rm_report_sm_xapp_api(int const handle);

// Send control message
// return void but sm_ag_if_ans_ctrl_t should be returned. Add it in the future if needed
sm_ans_xapp_t control_sm_xapp_api(global_e2_node_id_t* id, uint32_t rf_id, void* wr);

#ifdef __cplusplus
}
#endif

#endif

