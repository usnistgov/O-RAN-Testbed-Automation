/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */


#ifndef DATABASE_XAPP_GENERIC_H
#define DATABASE_XAPP_GENERIC_H 


#include "sqlite3/sqlite3_wrapper.h"



#define init_db_gen(T,U) _Generic ((T), \
                                    sqlite3*:  init_db_sqlite3, \
                                    default:   init_db_sqlite3) (T,U)

#define close_db_gen(T) _Generic ((T),\
                                    sqlite3*: close_db_sqlite3, \
                                    default:  close_db_sqlite3) (T)


#define write_db_gen(T,U,V) _Generic ((T),\
                                    sqlite3*:   write_db_sqlite3, \
                                    default:    write_db_sqlite3) (T,U,V)

#endif

