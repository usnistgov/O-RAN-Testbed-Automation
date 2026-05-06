/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#ifndef DATABASE_XAPP_H
#define DATABASE_XAPP_H 

#include "../../lib/e2ap/e2ap_global_node_id_wrapper.h"
#include "../../sm/agent_if/read/sm_ag_if_rd.h"
#include "../../util/alg_ds/ds/tsn_queue/tsn_queue.h"

#include <pthread.h>

#ifdef SQLITE3_XAPP
  #include "sqlite3/sqlite3.h"
#endif

typedef struct{

#ifdef SQLITE3_XAPP
  sqlite3* handler;
#else
  static_assert(0!=0, "Unknown DB selected for the xApp"); 
#endif

  pthread_t p;
  tsnq_t q;
} db_xapp_t;

void init_db_xapp(db_xapp_t* db, char const* db_filename);

void close_db_xapp(db_xapp_t* db);

void write_db_xapp(db_xapp_t* db, global_e2_node_id_t const* id, sm_ag_if_rd_t const* rd);

#endif

