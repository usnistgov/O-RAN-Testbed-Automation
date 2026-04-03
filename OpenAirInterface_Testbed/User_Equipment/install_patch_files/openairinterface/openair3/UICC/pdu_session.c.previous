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
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *-------------------------------------------------------------------------------
 * For more information about the OpenAirInterface (OAI) Software Alliance:
 *      contact@openairinterface.org
 */

#include <assert.h>

#include "pdu_session.h"
// we can't include the file for PDU session type defines, as it pulls in too
// much. However, we only use it for mapping types to integers, which are
// standard defined, so it should be ok.
//#include "openair3/NAS/NR_UE/5GS/5GSM/MSG/PduSessionEstablishmentAccept.h"
#include "common/utils/utils.h"
#include "common/config/config_paramdesc.h"
#include "common/config/config_userapi.h"


// clang-format off
// Note: Default PDU session ID 0 does not exist and will be replaced with PDU
// session index if not set to a parameter > 0!
#define PDU_SESS_PARAMS_DESC {                                              \
    {"id",        "PDU session ID\n",             0, .iptr=NULL,       .defintval=0,        TYPE_INT,    0}, \
    {"type",      "PDU session type\n",           0, .strptr=NULL,     .defstrval="IPv4",   TYPE_STRING, 0}, \
    {"nssai_sst", "NSSAI slice type\n",           0, .u8ptr=NULL,      .defintval=1,        TYPE_UINT8,  0}, \
    {"nssai_sd",  "NSSAI slice differentiator\n", 0, .uptr=NULL,       .defintval=0xffffff, TYPE_UINT32, 0}, \
    {"dnn",       "PDU session DNN (APN)\n",      0, .strptr=NULL,     .defstrval="oai",    TYPE_STRING, 0}, \
}

#define PDU_SESS_PARAMS_CHECK {                      \
    {.s2 = {config_check_intrange, {0, 255}}},       \
    {.s3a = {config_checkstr_assign_integer,         \
             {"IPv4", "IPv6", "IPv4v6", "Ethernet"}, \
             {1 /*PDU_SESSION_TYPE_IPV4*/,           \
              2 /*PDU_SESSION_TYPE_IPV6*/,           \
              3 /*PDU_SESSION_TYPE_IPV4V6*/,         \
              5 /*PDU_SESSION_TYPE_ETHER*/},         \
             4}},                                    \
    {.s2 = {config_check_intrange, {1, 4}}},         \
    {.s2 = {config_check_intrange, {1, 0xffffff}}},  \
    {.s4 = {config_check_dnn}},                      \
}
// clang-format on

static int config_check_dnn(configmodule_interface_t *cfg, paramdef_t *param)
{
  const char *dnn = *param->strptr;
  int dnn_len = strlen(dnn);
  if (dnn_len > 102) {
    printf("DNN '%s' exceeds max len of 102 (is %d) (TS 24.501 §9.11.2.1A)\n", dnn, dnn_len);
    return -1;
  }

  // check for valid characters in the APN (TS 23.003 §9.1)
  // we don't enforce all conditions
  const char *allowed = "abcdefghijklmnopqrstuvwxyz"
                        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        "0123456789.-";
  while (*dnn) {
    if (!strchr(allowed, *dnn)) {
      printf("character '%c' in DNN '%s' is not allowed (TS 23.003 §9.1)\n", *dnn, *param->strptr);
      return -1;
    }
    dnn++;
  }

  return 0;
}

int get_pdu_session_configs(const char *uiccName, pdu_session_config_t *configs, int max_len)
{
  paramdef_t pdu_sess_params[] = PDU_SESS_PARAMS_DESC;
  const int npsp = sizeofArray(pdu_sess_params);
  paramlist_def_t pdu_sess_list = {"pdu_sessions"};
  checkedparam_t pdu_sess_params_check[] = PDU_SESS_PARAMS_CHECK;
  static_assert(sizeofArray(pdu_sess_params) == sizeofArray(pdu_sess_params_check),
                "param_def_t array and corresponding checkedparam_t array should have the same size");
  for (int i = 0; i < sizeofArray(pdu_sess_params); ++i)
    pdu_sess_params[i].chkPptr = &pdu_sess_params_check[i];
  int ret = config_getlist(config_get_if(), &pdu_sess_list, pdu_sess_params, sizeofArray(pdu_sess_params), uiccName);
  if (ret < 0) {
    // couldn't load configuration from pdu_sessions, caller has to handle
    return -1;
  }

  int num = pdu_sess_list.numelt;
  AssertFatal(num <= max_len, "cannot handle more than %d PDU sessions\n", max_len);

  for (int i = 0; i < num; ++i) {
    pdu_session_config_t *pdu = configs + i;
    paramdef_t *p = pdu_sess_list.paramarray[i];
    int id = *gpd(p, npsp, "id")->iptr;
    pdu->id = id > 0 ? id : i + 1; // if not user-specified ID, use PDU session index
    pdu->type = config_get_processedint(config_get_if(), (paramdef_t *)gpd(p, npsp, "type"));
    pdu->nssai.sst = *gpd(p, npsp, "nssai_sst")->iptr;
    pdu->nssai.sd = *gpd(p, npsp, "nssai_sd")->iptr;
    pdu->dnn = strdup(*gpd(p, npsp, "dnn")->strptr);
  }

  return num;
}
