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

#include <stdint.h>
#include "common/config.h"
#include "oai/oai_data.h"
#include "alarms/alarms.h"

int netconf_data_init(const config_t *config);
int netconf_data_alarms_init(const alarm_t **alarms);
int netconf_data_free();

int netconf_data_update_full(const oai_data_t *oai);
int netconf_data_update_bwp_dl(const oai_data_t *oai);
int netconf_data_update_bwp_ul(const oai_data_t *oai);
int netconf_data_update_nrcelldu(const oai_data_t *oai);
int netconf_data_update_alarm(const alarm_t *alarm, int notification_id);
