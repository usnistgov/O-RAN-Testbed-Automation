/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#ifndef MAP_RIC_ID_H
#define MAP_RIC_ID_H 

#include "../../util/alg_ds/ds/assoc_container/assoc_generic.h"

#include "e2_node_ric_id.h"

#include "xapp_ric_id.h"
#include <pthread.h>


typedef struct
{
//  assoc_rb_tree_t tree; // key: ric_req_id | value:   xapp_ric_id_t

  bi_map_t bimap; // left: key:   e2_node_ric_req_t | value: xapp_ric_id_t
                  // right: key:  xapp_ric_id_t | value: e2_node_ric_req_t  
  pthread_rwlock_t rw;
} map_ric_id_t;


void init_map_ric_id(map_ric_id_t* map);

void free_map_ric_id( map_ric_id_t* map);

void add_map_ric_id(map_ric_id_t* map, e2_node_ric_id_t* node, xapp_ric_id_t* x);

void rm_map_ric_id(map_ric_id_t* map, xapp_ric_id_t const* ric_id);

//void rm_map_ric_id(map_ric_id_t* map, e2_node_ric_req_t* node); // uint16_t ric_req_id);

xapp_ric_id_xpct_t find_xapp_map_ric_id(map_ric_id_t* map, uint16_t ric_req_id);

e2_node_ric_id_t find_ric_req_map_ric_id(map_ric_id_t* map, xapp_ric_id_t* x);

// array of e2_node_ric_id_t 
seq_arr_t find_all_subs_map_ric_id(map_ric_id_t* map, uint16_t xapp_id); 

#endif

