/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/sm/slice_sm/slice_sm_id.h"
#include "../../../../src/util/alg_ds/alg/defer.h"
#include "../../../../src/util/time_now_us.h"

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <poll.h>

/*
static
void sm_cb_mac(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == MAC_STATS_V0); 

  int64_t now = time_now_us();
  printf("MAC ind_msg latency = %ld \n", now - rd->mac_stats.msg.tstamp);
}
*/

static
int new_queues = 0;

static
void sm_cb_rlc(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == INDICATION_MSG_AGENT_IF_ANS_V0);
  assert(rd->ind.type == RLC_STATS_V0); 

//  int64_t now = time_now_us();
//  printf("RLC ind_msg latency = %ld \n", now - rd->rlc_stats.msg.tstamp);


  rlc_ind_msg_t const* msg = &rd->ind.rlc.msg;

  for(size_t i =0; i < msg->len; ++i){
    rlc_radio_bearer_stats_t const* rb  = &msg->rb[i]; 
//    printf("rnti %d mode %d rbid %d rb->txbuf_occ_bytes %d wt = %d \n", rb->rnti, rb->mode, rb->rbid, rb->txbuf_occ_bytes, rb->txpdu_wt_ms);    /* current tx buffer occupancy in terms of amount of bytes (average: NOT IMPLEMENTED) */
    if(rb->txpdu_wt_ms > 10 && new_queues == 0)
      new_queues = 1;
  }


}

/*
static
void sm_cb_tc(sm_ag_if_rd_t const* rd)
{
  assert(rd != NULL);
  assert(rd->type == TC_STATS_V0); 

  int64_t now = time_now_us();

  printf("TC ind_msg latency = %ld \n", now - rd->tc_stats.msg.tstamp);
}
*/




/*
static
sm_ag_if_wr_t create_add_slice(void)
{
  sm_ag_if_wr_t ctrl_msg = {.type = SLICE_CTRL_REQ_V0 };
  ctrl_msg.slice_req_ctrl.hdr.dummy = 2;
 
  slice_ctrl_msg_t* sl_ctrl_msg = &ctrl_msg.slice_req_ctrl.msg;
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
sm_ag_if_wr_t create_assoc_slice(void)
{
  sm_ag_if_wr_t ctrl_msg = { .type = SLICE_CTRL_REQ_V0 };
  ctrl_msg.slice_req_ctrl.hdr.dummy = 2;
 
  slice_ctrl_msg_t* sl_ctrl_msg = &ctrl_msg.slice_req_ctrl.msg;
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

*/


static
tc_ctrl_msg_t gen_mod_bdp_pcr(void)
{
     	tc_ctrl_msg_t ans = {.type = TC_CTRL_SM_V0_PCR,  
		.pcr.act = TC_CTRL_ACTION_SM_V0_MOD};  

       	ans.pcr.mod.type = TC_PCR_5G_BDP; 
      	ans.pcr.mod.bdp.tstamp = time_now_us(); 
      	ans.pcr.mod.bdp.drb_sz = 25000; 
      	return ans;
}

static
tc_ctrl_msg_t gen_add_codel_queue(void)
{

  tc_ctrl_msg_t ans = {.type = TC_CTRL_SM_V0_QUEUE,
                       .q.act = TC_CTRL_ACTION_SM_V0_ADD}; 

  tc_add_ctrl_queue_t* q = &ans.q.add;

  q->type = TC_QUEUE_CODEL;

  q->codel.interval_ms = 400;
  q->codel.target_ms = 20;

  assert(ans.type ==  TC_CTRL_SM_V0_QUEUE );

  return ans;
}

static
tc_ctrl_msg_t gen_add_osi_cls(uint32_t dst_port ) 
{
  tc_ctrl_msg_t ans = {.type = TC_CTRL_SM_V0_CLS,
		.cls.act = TC_CTRL_ACTION_SM_V0_ADD}; 

	tc_add_ctrl_cls_t* add = &ans.cls.add; 
	add->type = TC_CLS_OSI;  
	add->osi.dst_queue = 1;
	add->osi.l3.src_addr = -1;  
	add->osi.l3.dst_addr = -1;
	add->osi.l4.src_port = -1; 
	add->osi.l4.dst_port = dst_port;
	add->osi.l4.protocol = -1;
	return ans;
}



int main()
{
  fr_args_t args = init_fr_args(1,NULL);
  //Init the xApp
  init_xapp_api(&args);
  sleep(1);

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  defer({ free_e2_node_arr_xapp(&nodes); });

  assert(nodes.len > 0);

  printf("Connected E2 nodes = %d\n", nodes.len );

  e2_node_connected_xapp_t* n = &nodes.n[0];
  for(size_t i = 0; i < n->len_rf; ++i)
    printf("Registered ran func id = %d \n ", n->rf[i].id );


  const char* i = "5_ms";
  sm_ans_xapp_t h = report_sm_xapp_api(&nodes.n[0].id, 143, (void*)i, sm_cb_rlc);
  assert(h.success == true);

  printf("Registered to RLC SM \n ");


  const int TC_SM_ID_TEST = 146;
  //int counter = 0;
//  for(int i =0; i < 10000; ++i){
  for(;;){
//	sm_ag_if_wr_t wr = {.type = TC_CTRL_REQ_V0 };
//        wr.tc_req_ctrl.msg = gen_mod_bdp_pcr();

//        control_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST, &wr);
//        free_tc_ctrl_msg(&wr.tc_req_ctrl.msg);


    if(new_queues == 1){
	printf("Delay at RLC buffer > 10 ms detected tstamp %ld \n", time_now_us() );
	// Pacer
	sm_ag_if_wr_t wr = {.type =CONTROL_SM_AG_IF_WR };
wr.ctrl.type = TC_CTRL_REQ_V0;

        wr.ctrl.tc_req_ctrl.msg = gen_mod_bdp_pcr();

        control_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST, &wr);
        free_tc_ctrl_msg(&wr.ctrl.tc_req_ctrl.msg);

	printf("PACER done tstamp %ld \n", time_now_us() );

	// Queue
	sm_ag_if_wr_t wr_q = {.type =CONTROL_SM_AG_IF_WR };
wr.ctrl.type = TC_CTRL_REQ_V0;

        wr_q.ctrl.tc_req_ctrl.msg = gen_add_codel_queue();

        control_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST, &wr_q);
        free_tc_ctrl_msg(&wr_q.ctrl.tc_req_ctrl.msg);

	printf("Queue done tstamp %ld \n", time_now_us() );


	// Classifier
	wr.type =CONTROL_SM_AG_IF_WR; 
  wr.ctrl.type = TC_CTRL_REQ_V0;

	uint32_t dst_port = 5201; 
        wr.ctrl.tc_req_ctrl.msg = gen_add_osi_cls(dst_port);

        control_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST, &wr);
        free_tc_ctrl_msg(&wr.ctrl.tc_req_ctrl.msg);

	printf("Classifier done tstamp %ld \n", time_now_us() );

	/*
	for(int i =0; i < 8; ++i){
	// Classifier
	wr.type = TC_CTRL_REQ_V0;
	uint32_t src_port = 9091; 
        wr.tc_req_ctrl.msg = gen_add_osi_cls(src_port + i);

        control_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST, &wr);
        free_tc_ctrl_msg(&wr.tc_req_ctrl.msg);
	}
*/

	//tc_ctrl_msg_t gen_add_osi_cls(void) 

      // Queues
//      for(int i = 0; i < 3; ++i){
        //      }
	new_queues = 2; 
//	break;
    }

    poll(NULL, 0, 10);
  }




//  inter_xapp_e i = ms_1;
//  const int TC_SM_ID_TEST = 146;

  // returns a handle
//  sm_ans_xapp_t h = report_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST , i, sm_cb_tc);
//  assert(h.success == true);
//  sleep(2);

/*
  for(int i = 0; i < 3; ++i){
    sm_ag_if_wr_t wr = {.type = TC_CTRL_REQ_V0 };
    wr.tc_req_ctrl.msg = gen_add_codel_queue();

    control_sm_xapp_api(&nodes.n[0].id, TC_SM_ID_TEST, &wr);
    free_tc_ctrl_msg(&wr.tc_req_ctrl.msg);
  }

  printf("3 new queues created \n");


  sleep(2);
*/

/*
  inter_xapp_e i_2 = ms_1;
  // returns a handle
  sm_ans_xapp_t h_2 = report_sm_xapp_api(&nodes.n[0].id, n->ack_rf[1].id, i_2, sm_cb_rlc);
  assert(h_2.success == true);

  inter_xapp_e i_3 = ms_1;
  // returns a handle
  sm_ans_xapp_t h_3 = report_sm_xapp_api(&nodes.n[1].id, n->ack_rf[0].id, i_3, sm_cb_mac);
  assert(h_2.success == true);
  sleep(2);

  // Control ADD slice
  sm_ag_if_wr_t ctrl_msg_add = create_add_slice();
  control_sm_xapp_api(&nodes.n[0].id, SM_SLICE_ID, &ctrl_msg_add);
  free(ctrl_msg_add.slice_req_ctrl.msg.u.add_mod_slice.dl.slices); 
  free(ctrl_msg_add.slice_req_ctrl.msg.u.add_mod_slice.dl.sched_name);

  sleep(1);

  // Control ASSOC slice
  sm_ag_if_wr_t ctrl_msg_assoc = create_assoc_slice();
  control_sm_xapp_api(&nodes.n[0].id, SM_SLICE_ID, &ctrl_msg_assoc);
  free(ctrl_msg_assoc.slice_req_ctrl.msg.u.ue_slice.ues); 

  sleep(1);
*/
  // Remove the handle previously returned
//  rm_report_sm_xapp_api(h.u.handle);

  // Remove the handle previously returned
 // rm_report_sm_xapp_api(h_2.u.handle);

  // Remove the handle previously returned
 // rm_report_sm_xapp_api(h_3.u.handle);

//  sleep(30);

  //Stop the xApp
  while(try_stop_xapp_api() == false)
    usleep(1000);     

  printf("Test xApp run SUCCESSFULLY\n");
}


