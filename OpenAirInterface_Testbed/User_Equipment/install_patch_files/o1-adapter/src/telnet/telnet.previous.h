/*
* Licensed to the OpenAirInterface (OAI) Software Alliance under one or more
* contributor license agreements.  See the NOTICE file distributed with
* this work for additional information regarding copyright ownership.
* The OpenAirInterface Software Alliance licenses this file to You under
* the OAI Public License, Version 1.1  (the "License"); you may not use this file
* except in compliance with the License.
* You may obtain a copy of the License at
*
*      http://www.openairinterface.org/?page_id=698
*
* Copyright: Fraunhofer Heinrich Hertz Institute
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*-------------------------------------------------------------------------------
* For more information about the OpenAirInterface (OAI) Software Alliance:
*      contact@openairinterface.org
*/

#pragma once

typedef enum {
    TELNET_ON_CONNECTED,        // gracefully started
    TELNET_ON_DISCONNECTED,     // gracefully disconneted
    TELNET_ON_CLOSED,           // ungracefully disconnected
    TELNET_ON_DATA,             // unrequested data received
} telnet_on_event_type_t;

typedef void(*telnet_on_event_t)(void);
typedef void(*telnet_on_data_t)(const char *data);

int telnet_local_init();
int telnet_local_free();

int telnet_local_connect(const char *hostname, int port);
int telnet_local_disconnect();
int telnet_local_is_connected();

int telnet_local_register_callback(telnet_on_event_type_t event, telnet_on_event_t callback);

int telnet_local_wait_for_prompt();

char *telnet_get_o1_stats();
int telnet_change_bandwidth(int new_bandwidth);



int telnet_test_ls();
