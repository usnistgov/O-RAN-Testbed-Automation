/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "../../../../src/xApp/e42_xapp_api.h"
#include "../../../../src/util/alg_ds/alg/defer.h"
#include "../../../../src/util/ngran_types.h"

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>

int main(int argc, char *argv[])
{
  fr_args_t args = init_fr_args(argc, argv);

  //Init the xApp
  init_xapp_api(&args);
  sleep(1);

  e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
  defer({ free_e2_node_arr_xapp(&nodes); });

  assert(nodes.len > 0);

  printf("Connected E2 nodes = %d\n", nodes.len);
  for (size_t i = 0; i < nodes.len; i++) {
    ngran_node_t ran_type = nodes.n[i].id.type;
    if (NODE_IS_MONOLITHIC(ran_type))
      printf("E2 node %ld info: nb_id %d, mcc %d, mnc %d, mnc_digit_len %d, ran_type %s\n",
             i,
             nodes.n[i].id.nb_id.nb_id,
             nodes.n[i].id.plmn.mcc,
             nodes.n[i].id.plmn.mnc,
             nodes.n[i].id.plmn.mnc_digit_len,
             get_ngran_name(ran_type));
    else
      printf("E2 node %ld info: nb_id %d, mcc %d, mnc %d, mnc_digit_len %d, ran_type %s, cu_du_id %lu\n",
             i,
             nodes.n[i].id.nb_id.nb_id,
             nodes.n[i].id.plmn.mcc,
             nodes.n[i].id.plmn.mnc,
             nodes.n[i].id.plmn.mnc_digit_len,
             get_ngran_name(ran_type),
             *nodes.n[i].id.cu_du_id);

    printf("E2 node %ld supported RAN function's IDs:", i);
    for (size_t j = 0; j < nodes.n[i].len_rf; j++)
      printf(", %d", nodes.n[i].rf[j].id);
    printf("\n");
  }


  printf("Hello World\n");

  //Stop the xApp
  while(try_stop_xapp_api() == false)
    usleep(1000);

  printf("Test xApp run SUCCESSFULLY\n");
}

