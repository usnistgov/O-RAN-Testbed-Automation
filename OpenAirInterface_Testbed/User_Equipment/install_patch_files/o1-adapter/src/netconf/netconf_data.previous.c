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

#define _GNU_SOURCE
#include "netconf_data.h"
#include "netconf.h"
#include "common/log.h"
#include "netconf_session.h"
#include "telnet/telnet.h"

#include <sysrepo.h>
#include <libyang/libyang.h>

#define MAX_XPATH_ENTRIES 200

static char *xpath_running[MAX_XPATH_ENTRIES] = {0};
static char *values_running[MAX_XPATH_ENTRIES] = {0};

static char *xpath_operational[MAX_XPATH_ENTRIES] = {0};
static char *values_operational[MAX_XPATH_ENTRIES] = {0};

static const char *MANAGED_ELEMENT_XPATH = 0;
static const char *MANAGED_ELEMENT_XPATH_OPER = 0;
static const char *GNBDU_FUNCTION_XPATH = 0;
static const char *BWP_DOWNLINK_XPATH = 0;
static const char *BWP_UPLINK_XPATH = 0;
static const char *NRCELLDU_XPATH = 0;
static const char *NPNIDENTITYLIST_XPATH = 0;
static const char *ALARMLIST_XPATH = 0;
static const char **ALARM_XPATH = 0;
static const char **ALARM_XPATH_OPER = 0;

static const char *NRSECTORCARRIER_XPATH = 0;


static const config_t *netconf_config = 0;
static const alarm_t **netconf_alarms = 0;
static sr_subscription_ctx_t *netconf_data_subscription = 0;

static int netconf_data_register_callbacks();
static int netconf_data_unregister_callbacks();
static int netconf_data_edit_callback(sr_session_ctx_t *session, uint32_t sub_id, const char *module_name, const char *xpath_running, sr_event_t event, uint32_t request_id, void *private_data);

int netconf_data_init(const config_t *config) {
    if(config == 0) {
        log_error("config is null");
        goto failure;
    }

    netconf_config = config;
    netconf_alarms = 0;
    netconf_data_subscription = 0;

    MANAGED_ELEMENT_XPATH = 0;
    MANAGED_ELEMENT_XPATH_OPER = 0;
    GNBDU_FUNCTION_XPATH = 0;
    BWP_DOWNLINK_XPATH = 0;
    BWP_UPLINK_XPATH = 0;
    NRCELLDU_XPATH = 0;
    NPNIDENTITYLIST_XPATH = 0;
    ALARM_XPATH = 0;
    ALARM_XPATH_OPER = 0;

    NRSECTORCARRIER_XPATH = 0;
    return 0;

failure:
    return 1;
}

int netconf_data_alarms_init(const alarm_t **alarms) {
    int alarms_no = 0;
    netconf_alarms = alarms;
    while(*netconf_alarms) {
        netconf_alarms++;
        alarms_no++;
    }

    netconf_alarms = alarms;

    ALARM_XPATH = (const char**)malloc(sizeof(char *) * alarms_no);
    if(ALARM_XPATH == 0) {
        log_error("malloc failed");
        goto failed;
    }

    for(int i = 0; i < alarms_no; i++) {
        ALARM_XPATH[i] = 0;
    }

    ALARM_XPATH_OPER = (const char**)malloc(sizeof(char *) * alarms_no);
    if(ALARM_XPATH_OPER == 0) {
        log_error("malloc failed");
        goto failed;
    }

    for(int i = 0; i < alarms_no; i++) {
        ALARM_XPATH_OPER[i] = 0;
    }

    return 0;
failed:
    free(ALARM_XPATH);
    ALARM_XPATH = 0;
    free(ALARM_XPATH_OPER);
    ALARM_XPATH_OPER = 0;
    return 1;
}

int netconf_data_free() {
    for(int i = 0; i < MAX_XPATH_ENTRIES; i++) {
        free(xpath_running[i]);
        xpath_running[i] = 0;
        free(values_running[i]);
        values_running[i] = 0;

        free(xpath_operational[i]);
        xpath_operational[i] = 0;
        free(values_operational[i]);
        values_operational[i] = 0;
    }

    free(ALARM_XPATH);
    ALARM_XPATH = 0;

    free(ALARM_XPATH_OPER);
    ALARM_XPATH_OPER = 0;

    MANAGED_ELEMENT_XPATH = 0;
    MANAGED_ELEMENT_XPATH_OPER = 0;
    GNBDU_FUNCTION_XPATH = 0;
    BWP_DOWNLINK_XPATH = 0;
    BWP_UPLINK_XPATH = 0;
    NRCELLDU_XPATH = 0;
    NPNIDENTITYLIST_XPATH = 0;
    ALARMLIST_XPATH = 0;
    
    NRSECTORCARRIER_XPATH = 0;
 

    netconf_data_unregister_callbacks();

    return 0;
}

int netconf_data_update_full(const oai_data_t *oai) {
    int rc = 0;

    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    if(MANAGED_ELEMENT_XPATH) {
        rc = sr_delete_item(netconf_session_running, MANAGED_ELEMENT_XPATH, SR_EDIT_STRICT);
        if(rc != SR_ERR_OK) {
            log_error("sr_delete_item failure");
            goto failure;
        }

        rc = sr_apply_changes(netconf_session_running, 0);
        if(rc != SR_ERR_OK) {
            log_error("sr_apply_changes failed");
            goto failure;
        }
    }

    for(int i = 0; i < MAX_XPATH_ENTRIES; i++) {
        free(xpath_running[i]);
        xpath_running[i] = 0;
        free(values_running[i]);
        values_running[i] = 0;

        free(xpath_operational[i]);
        xpath_operational[i] = 0;
        free(values_operational[i]);
        values_operational[i] = 0;
    }

    MANAGED_ELEMENT_XPATH = 0;
    MANAGED_ELEMENT_XPATH_OPER = 0;
    GNBDU_FUNCTION_XPATH = 0;
    BWP_DOWNLINK_XPATH = 0;
    BWP_UPLINK_XPATH = 0;
    NRCELLDU_XPATH = 0;
    NPNIDENTITYLIST_XPATH = 0;
    ALARMLIST_XPATH = 0;
    
    NRSECTORCARRIER_XPATH = 0;

    int k_running = 0, k_operational = 0;

    asprintf(&xpath_running[k_running], "/_3gpp-common-managed-element:ManagedElement[id='ManagedElement=%s']", netconf_config->info.node_id);
    if(xpath_running[k_running] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    MANAGED_ELEMENT_XPATH = xpath_running[k_running];
    k_running++;

    asprintf(&xpath_operational[k_operational], "/_3gpp-common-managed-element:ManagedElement[id='ManagedElement=%s']", netconf_config->info.node_id);
    if(xpath_operational[k_operational] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    MANAGED_ELEMENT_XPATH_OPER = xpath_operational[k_operational];
    k_operational++;
        
        values_running[k_running] = strdup("1");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", MANAGED_ELEMENT_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_operational[k_running], "ip-v4-address=%s", netconf_config->network.host);
        if(values_operational[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_running], "%s/attributes/dnPrefix", MANAGED_ELEMENT_XPATH);
        if(xpath_operational[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        values_operational[k_operational] = strdup(netconf_config->info.location_name);
        if(values_operational[k_operational] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/attributes/locationName", MANAGED_ELEMENT_XPATH_OPER);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        values_operational[k_operational] = strdup(netconf_config->info.managed_by);
        if(values_operational[k_operational] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/attributes/managedBy", MANAGED_ELEMENT_XPATH_OPER);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        values_operational[k_operational] = strdup(netconf_config->info.managed_element_type);
        if(values_operational[k_operational] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/attributes/managedElementTypeList", MANAGED_ELEMENT_XPATH_OPER);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        values_operational[k_operational] = strdup(oai->device_data.vendor);
        if(values_operational[k_operational] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/attributes/vendorName", MANAGED_ELEMENT_XPATH_OPER);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        values_operational[k_operational] = strdup(netconf_config->software_version);
        if(values_operational[k_operational] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/attributes/swVersion", MANAGED_ELEMENT_XPATH_OPER);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups", MANAGED_ELEMENT_XPATH_OPER);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

            values_operational[k_operational] = strdup("DRB.UEThpDl");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/performanceMetrics", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("DRB.UEThpUl");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/performanceMetrics", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("DRB.MeanActiveUeDl");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/performanceMetrics", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("DRB.MaxActiveUeDl");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/performanceMetrics", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("DRB.MeanActiveUeUl");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/performanceMetrics", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("DRB.MaxActiveUeUl");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/performanceMetrics", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("900");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/granularityPeriods", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("FILE_BASED_LOC_SET_BY_PRODUCER");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/reportingMethods", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            values_operational[k_operational] = strdup("FILE_BASED_LOC_SET_BY_CONSUMER");
            if(values_operational[k_operational] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/attributes/SupportedPerfMetricGroups/reportingMethods", MANAGED_ELEMENT_XPATH_OPER);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

        asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-gnbdufunction:GNBDUFunction[id='ManagedElement=%s,GNBDUFunction=%d']", MANAGED_ELEMENT_XPATH, netconf_config->info.node_id, netconf_config->info.gnb_du_id);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        GNBDU_FUNCTION_XPATH = xpath_running[k_running];
        k_running++;

            values_running[k_running] = strdup("1");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            asprintf(&values_running[k_running], "%d", oai->device_data.gnbId);
            if(values_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/attributes/gNBId", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            values_running[k_running] = strdup("32");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/attributes/gNBIdLength", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            asprintf(&values_running[k_running], "%d", netconf_config->info.gnb_du_id);
            if(values_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/attributes/gNBDUId", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            asprintf(&values_running[k_running], "%s-DU-%d", oai->device_data.gnbName, netconf_config->info.gnb_du_id);
            if(values_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/attributes/gNBDUName", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-bwp:BWP[id='Downlink']", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            BWP_DOWNLINK_XPATH = xpath_running[k_running];
            k_running++;

                values_running[k_running] = strdup("1");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->bwp[0].subCarrierSpacing);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/subCarrierSpacing", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%s", "DL");
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/bwpContext", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                values_running[k_running] = strdup((oai->bwp[0].isInitialBwp) ? "INITIAL" : "OTHER");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/isInitialBwp", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                values_running[k_running] = strdup("NORMAL");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/cyclicPrefix", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->bwp[0].startRB);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/startRB", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->bwp[0].numberOfRBs);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/numberOfRBs", BWP_DOWNLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

            asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-bwp:BWP[id='Uplink']", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            BWP_UPLINK_XPATH = xpath_running[k_running];
            k_running++;

                values_running[k_running] = strdup("1");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->bwp[1].subCarrierSpacing);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/subCarrierSpacing", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%s", "UL");
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/bwpContext", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                values_running[k_running] = strdup((oai->bwp[1].isInitialBwp) ? "INITIAL" : "OTHER");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/isInitialBwp", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                values_running[k_running] = strdup("NORMAL");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/cyclicPrefix", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->bwp[1].startRB);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/startRB", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->bwp[1].numberOfRBs);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/numberOfRBs", BWP_UPLINK_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

            asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-nrcelldu:NRCellDU[id='ManagedElement=%s,GNBDUFunction=%d,NRCellDu=0']", GNBDU_FUNCTION_XPATH, netconf_config->info.node_id, netconf_config->info.gnb_du_id);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            NRCELLDU_XPATH = xpath_running[k_running];
            k_running++;

                values_running[k_running] = strdup("1");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", netconf_config->info.cell_local_id);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/cellLocalId", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                char sdHex[9];
                sprintf(sdHex, "%06x", oai->nrcelldu.sd);

                sdHex[8] = 0;
                sdHex[7] = sdHex[5];
                sdHex[6] = sdHex[4];
                sdHex[5] = ':';
                sdHex[4] = sdHex[3];
                sdHex[3] = sdHex[2];
                sdHex[2] = ':';

                asprintf(&xpath_running[k_running], "%s/attributes/pLMNInfoList[mcc='%s'][mnc='%s'][sd='%s'][sst='%d']", NRCELLDU_XPATH, oai->nrcelldu.mcc, oai->nrcelldu.mnc, sdHex, oai->nrcelldu.sst);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&xpath_running[k_running], "%s/attributes/nPNIdentityList[idx='%d']", NRCELLDU_XPATH, 0);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                NPNIDENTITYLIST_XPATH = xpath_running[k_running];
                k_running++;

                    asprintf(&xpath_running[k_running], "%s/plmnid[mcc='%s'][mnc='%s']", NPNIDENTITYLIST_XPATH, oai->nrcelldu.mcc, oai->nrcelldu.mnc);
                    if(xpath_running[k_running] == 0) {
                        log_error("asprintf failed");
                        goto failure;
                    }
                    k_running++;

                    values_running[k_running] = strdup("1");
                    if(values_running[k_running] == 0) {
                        log_error("strdup failed");
                        goto failure;
                    }
                    asprintf(&xpath_running[k_running], "%s/cAGIdList", NPNIDENTITYLIST_XPATH);
                    if(xpath_running[k_running] == 0) {
                        log_error("asprintf failed");
                        goto failure;
                    }
                    k_running++;

                    values_running[k_running] = strdup("1");
                    if(values_running[k_running] == 0) {
                        log_error("strdup failed");
                        goto failure;
                    }
                    asprintf(&xpath_running[k_running], "%s/nIDList", NPNIDENTITYLIST_XPATH);
                    if(xpath_running[k_running] == 0) {
                        log_error("asprintf failed");
                        goto failure;
                    }
                    k_running++;

                asprintf(&values_running[k_running], "%d", oai->nrcelldu.nRPCI);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/nRPCI", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->nrcelldu.arfcnDL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/arfcnDL", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->nrcelldu.arfcnUL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/arfcnUL", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->nrcelldu.bSChannelBwDL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/bSChannelBwDL", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->nrcelldu.bSChannelBwUL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/bSChannelBwUL", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "2023-06-06T00:00:00Z");   //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringStartTime", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "2023-06-06T00:00:00Z");   //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringStopTime", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringWindowDuration", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringWindowStartingOffset", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringWindowPeriodicity", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringOccasionInterval", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringOccasionStartingOffset", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", oai->nrcelldu.ssbFrequency);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/ssbFrequency", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 5);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/ssbPeriodicity", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 15);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/ssbSubCarrierSpacing", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/ssbOffset", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "%d", 1);  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/ssbDuration", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "Tuf=Jy,H:u=|");  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/nRSectorCarrierRef", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "Tuf=Jy,H:u=|");  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/victimSetRef", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

                asprintf(&values_running[k_running], "Tuf=Jy,H:u=|");  //checkAL
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/aggressorSetRef", NRCELLDU_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

/* **********************************************POPULATING NR SECTOR CARRIER CONFIGS************************************************ */
asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-nrsectorcarrier:NRSectorCarrier[id='ManagedElement=%s, GNBDUFunction=%d']", GNBDU_FUNCTION_XPATH);
            if(xpath_running[k_running] == 0) {
                  log_error("asprintf failed");
                  goto failure;
            }

            NRSECTORCARRIER_XPATH = xpath_running[k_running];
            k_running++;

	    values_running[k_running] = strdup("1");
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", NRSECTORCARRIER_XPATH);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;
asprintf(&values_running[k_running], "%d", oai->nrsectcarr.txDirection);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("UL");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/txDirection", NRSECTORCARRIER_XPATH);
            if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;


 asprintf(&values_running[k_running], "%s", oai->nrsectcarr.configuredMaxTxPower);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("50");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/configuredMaxTxPower", NRSECTORCARRIER_XPATH);
            if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

 asprintf(&values_running[k_running], "%d", oai->nrsectcarr.configuredMaxTxEIRP);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("100");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/configuredMaxTxEIRP", NRSECTORCARRIER_XPATH);
            if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;



 asprintf(&values_running[k_running], "%d", oai->nrsectcarr.arfcnDL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("104");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/arfcnDL", NRSECTORCARRIER_XPATH);
            if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

 asprintf(&values_running[k_running], "%d", oai->nrsectcarr.arfcnUL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("104");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/arfcnUL", NRSECTORCARRIER_XPATH);
            if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;
		
asprintf(&values_running[k_running], "%d", oai->nrsectcarr.bSChannelBwDL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("60");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/bSChannelBwDL", NRSECTORCARRIER_XPATH);                 if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

		asprintf(&values_running[k_running], "%d", oai->nrsectcarr.bSChannelBwUL);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("60");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/bSChannelBwUL", NRSECTORCARRIER_XPATH);                 if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

		                asprintf(&values_running[k_running], "%s", oai->nrsectcarr.sectorEquipmentFunctionRef);
                if(values_running[k_running] == 0) {
                    log_error("asprintf failed");
                goto failure;
           }

            values_running[k_running] = strdup("Tuf=Jy,H:u=|");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }

            asprintf(&xpath_running[k_running], "%s/attributes/sectorEquipmentFunctionRef", NRSECTORCARRIER_XPATH);                 if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;




        asprintf(&xpath_running[k_running], "%s/_3gpp-common-managed-element:AlarmList[id='ManagedElement=%s,AlarmList=1']", MANAGED_ELEMENT_XPATH, netconf_config->info.node_id);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        ALARMLIST_XPATH = xpath_running[k_running];
        k_running++;

        asprintf(&xpath_operational[k_operational], "%s/_3gpp-common-managed-element:AlarmList[id='ManagedElement=%s,AlarmList=1']", MANAGED_ELEMENT_XPATH, netconf_config->info.node_id);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;


        const alarm_t **alarm = netconf_alarms;
        int i = 0;
        while(*alarm) {
            asprintf(&xpath_running[k_running], "%s/attributes/alarmRecords[alarmId='%s-%s']", ALARMLIST_XPATH, (*alarm)->object_instance, (*alarm)->alarm);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            ALARM_XPATH[i] = xpath_running[k_running];
            k_running++;

                alarm_severity_t severity = ALARM_SEVERITY_CLEARED;
                if((*alarm)->state != ALARM_STATE_CLEARED) {
                    severity = (*alarm)->severity;
                }

                values_running[k_running] = strdup(alarm_severity_to_str(severity));
                if(values_running[k_running] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_running[k_running], "%s/perceivedSeverity", ALARM_XPATH[i]);
                if(xpath_running[k_running] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_running++;

            asprintf(&xpath_operational[k_operational], "%s/attributes/alarmRecords[alarmId='%s-%s']", ALARMLIST_XPATH, (*alarm)->object_instance, (*alarm)->alarm);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            ALARM_XPATH_OPER[i] = xpath_operational[k_operational];
            k_operational++;

                values_operational[k_operational] = strdup((*alarm)->object_instance);
                if(values_operational[k_operational] == 0) {
                    log_error("strdup failed");
                    goto failure;
                }
                asprintf(&xpath_operational[k_operational], "%s/objectInstance", ALARM_XPATH_OPER[i]);
                if(xpath_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_operational++;

                asprintf(&values_operational[k_operational], "0");
                if(values_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_operational[k_operational], "%s/notificationId", ALARM_XPATH_OPER[i]);
                if(xpath_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_operational++;

                values_operational[k_operational] = strdup(alarm_type_to_str((*alarm)->type));
                if(values_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_operational[k_operational], "%s/alarmType", ALARM_XPATH_OPER[i]);
                if(xpath_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_operational++;

                values_operational[k_operational] = strdup("unset");
                if(values_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                asprintf(&xpath_operational[k_operational], "%s/probableCause", ALARM_XPATH_OPER[i]);
                if(xpath_operational[k_operational] == 0) {
                    log_error("asprintf failed");
                    goto failure;
                }
                k_operational++;

                // alarmChangedTime - not set until data is available
                k_operational++;
                // alarmRaisedTime - not set until data is available
                k_operational++;
                // alarmClearedTime - not set until data is available
                k_operational++;


            i++;
            alarm++;
        }

    if(k_running) {
        for (int i = 0; i < k_running; i++) {
            if(xpath_running[i]) {
                log("[runn] populating %s with %s.. ", xpath_running[i], values_running[i]);
                rc = sr_set_item_str(netconf_session_running, xpath_running[i], values_running[i], 0, 0);
                if(rc != SR_ERR_OK) {
                    log_error("sr_set_item_str failed");
                    goto failure;
                }
            }
        }

        rc = sr_apply_changes(netconf_session_running, 0);
        if(rc != SR_ERR_OK) {
            log_error("sr_apply_changes failed");
            goto failure;
        }
    }

    if(k_operational) {
        for (int i = 0; i < k_operational; i++) {
            if(xpath_operational[i]) {
                log("[oper] populating %s with %s.. ", xpath_operational[i], values_operational[i]);
                rc = sr_set_item_str(netconf_session_operational, xpath_operational[i], values_operational[i], 0, 0);
                if(rc != SR_ERR_OK) {
                    log_error("sr_set_item_str failed");
                    goto failure;
                }
            }
        }

        rc = sr_apply_changes(netconf_session_operational, 0);
        if(rc != SR_ERR_OK) {
            log_error("sr_apply_changes failed");
            goto failure;
        }
    }

    rc = netconf_data_register_callbacks();
    if(rc != 0) {
        log_error("netconf_data_register_callbacks");
        goto failure;
    }

    return 0;

failure:
    for(int i = 0; i < k_running; i++) {
        free(xpath_running[i]);
        xpath_running[i] = 0;
        free(values_running[i]);
        values_running[i] = 0;
    }

    for(int i = 0; i < k_operational; i++) {
        free(xpath_operational[i]);
        xpath_operational[i] = 0;
        free(values_operational[i]);
        values_operational[i] = 0;
    }

    MANAGED_ELEMENT_XPATH = 0;
    GNBDU_FUNCTION_XPATH = 0;
    BWP_DOWNLINK_XPATH = 0;
    BWP_UPLINK_XPATH = 0;
    NRCELLDU_XPATH = 0;
    NPNIDENTITYLIST_XPATH = 0;
    ALARMLIST_XPATH = 0;

    NRSECTORCARRIER_XPATH = 0 ;
    
    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    return 1;
}

int netconf_data_update_bwp_dl(const oai_data_t *oai) {
    int rc = 0;

    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    if(oai == 0) {
        log_error("oai is null");
        goto failure;
    }

    if(BWP_DOWNLINK_XPATH == 0) {
        log_error("BWP_DOWNLINK_XPATH is null");
        goto failure;
    }

    // find k_running
    int k_running = 0;
    while(k_running < MAX_XPATH_ENTRIES) {
        if(xpath_running[k_running] == BWP_DOWNLINK_XPATH) {
            break;
        }
        k_running++;
    }
    
    if(k_running >= MAX_XPATH_ENTRIES) {
        log_error("BWP_DOWNLINK_XPATH not found among running xpaths");
        goto failure;
    }

    int start_k_running = k_running;
    int stop_k_running = k_running;
    while(xpath_running[stop_k_running] && strstr(xpath_running[stop_k_running], BWP_DOWNLINK_XPATH) == xpath_running[stop_k_running]) {
        stop_k_running++;
    }

    rc = sr_delete_item(netconf_session_running, BWP_DOWNLINK_XPATH, SR_EDIT_STRICT);
    if(rc != SR_ERR_OK) {
        log_error("sr_delete_item failure");
        goto failure;
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    for (int i = start_k_running; i < stop_k_running; i++) {
        free(values_running[i]);
        free(xpath_running[i]);
        values_running[i] = 0;
        xpath_running[i] = 0;
    }

    asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-bwp:BWP[id='Downlink']", GNBDU_FUNCTION_XPATH);
    if(xpath_running[k_running] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    BWP_DOWNLINK_XPATH = xpath_running[k_running];
    k_running++;

        values_running[k_running] = strdup("1");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->bwp[0].subCarrierSpacing);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/subCarrierSpacing", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%s", "DL");
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/bwpContext", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        values_running[k_running] = strdup((oai->bwp[0].isInitialBwp) ? "INITIAL" : "OTHER");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/isInitialBwp", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        values_running[k_running] = strdup("NORMAL");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/cyclicPrefix", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->bwp[0].startRB);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/startRB", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->bwp[0].numberOfRBs);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/numberOfRBs", BWP_DOWNLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

    for (int i = start_k_running; i < stop_k_running; i++) {
        if(xpath_running[i]) {
            log("[runn] populating %s with %s.. ", xpath_running[i], values_running[i]);
            rc = sr_set_item_str(netconf_session_running, xpath_running[i], values_running[i], 0, 0);
            if(rc != SR_ERR_OK) {
                log_error("sr_set_item_str failed");
                goto failure;
            }
        }
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    rc = netconf_data_register_callbacks();
    if(rc != 0) {
        log_error("netconf_data_register_callbacks");
        goto failure;
    }

    return 0;

failure:
    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    return 1;
}

int netconf_data_update_bwp_ul(const oai_data_t *oai) {
    int rc = 0;

    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    if(oai == 0) {
        log_error("oai is null");
        goto failure;
    }

    if(BWP_UPLINK_XPATH == 0) {
        log_error("BWP_UPLINK_XPATH is null");
        goto failure;
    }

    // find k
    int k_running = 0;
    while(k_running < MAX_XPATH_ENTRIES) {
        if(xpath_running[k_running] == BWP_UPLINK_XPATH) {
            break;
        }
        k_running++;
    }
    
    if(k_running >= MAX_XPATH_ENTRIES) {
        log_error("BWP_UPLINK_XPATH not found among running xpaths");
        goto failure;
    }

    int start_k_running = k_running;
    int stop_k_running = k_running;
    while(xpath_running[stop_k_running] && strstr(xpath_running[stop_k_running], BWP_UPLINK_XPATH) == xpath_running[stop_k_running]) {
        stop_k_running++;
    }

    rc = sr_delete_item(netconf_session_running, BWP_UPLINK_XPATH, SR_EDIT_STRICT);
    if(rc != SR_ERR_OK) {
        log_error("sr_delete_item failure");
        goto failure;
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    for (int i = start_k_running; i < stop_k_running; i++) {
        free(values_running[i]);
        free(xpath_running[i]);
        values_running[i] = 0;
        xpath_running[i] = 0;
    }

    asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-bwp:BWP[id='Uplink']", GNBDU_FUNCTION_XPATH);
    if(xpath_running[k_running] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    BWP_UPLINK_XPATH = xpath_running[k_running];
    k_running++;

        values_running[k_running] = strdup("1");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->bwp[1].subCarrierSpacing);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/subCarrierSpacing", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%s", "UL");
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/bwpContext", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        values_running[k_running] = strdup((oai->bwp[1].isInitialBwp) ? "INITIAL" : "OTHER");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/isInitialBwp", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        values_running[k_running] = strdup("NORMAL");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/cyclicPrefix", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->bwp[1].startRB);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/startRB", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->bwp[1].numberOfRBs);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/numberOfRBs", BWP_UPLINK_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

    for (int i = start_k_running; i < stop_k_running; i++) {
        if(xpath_running[i]) {
            log("[runn] populating %s with %s.. ", xpath_running[i], values_running[i]);
            rc = sr_set_item_str(netconf_session_running, xpath_running[i], values_running[i], 0, 0);
            if(rc != SR_ERR_OK) {
                log_error("sr_set_item_str failed");
                goto failure;
            }
        }
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    rc = netconf_data_register_callbacks();
    if(rc != 0) {
        log_error("netconf_data_register_callbacks");
        goto failure;
    }

    return 0;

failure:
    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    return 1;
}

int netconf_data_update_nrcelldu(const oai_data_t *oai) {
    int rc = 0;

    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    if(oai == 0) {
        log_error("oai is null");
        goto failure;
    }

    if(NRCELLDU_XPATH == 0) {
        log_error("NRCELLDU_XPATH is null");
        goto failure;
    }

    // find k
    int k_running = 0;
    while(k_running < MAX_XPATH_ENTRIES) {
        if(xpath_running[k_running] == NRCELLDU_XPATH) {
            break;
        }
        k_running++;
    }
    
    if(k_running >= MAX_XPATH_ENTRIES) {
        log_error("NRCELLDU_XPATH not found among running xpaths");
        goto failure;
    }

    int start_k_running = k_running;
    int stop_k_running = k_running;
    while((xpath_running[stop_k_running]) && (strstr(xpath_running[stop_k_running], NRCELLDU_XPATH) == xpath_running[stop_k_running])) {
        stop_k_running++;
    }

    rc = sr_delete_item(netconf_session_running, NRCELLDU_XPATH, SR_EDIT_STRICT);
    if(rc != SR_ERR_OK) {
        log_error("sr_delete_item failure");
        goto failure;
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    for (int i = start_k_running; i < stop_k_running; i++) {
        free(values_running[i]);
        free(xpath_running[i]);
        values_running[i] = 0;
        xpath_running[i] = 0;
    }

    asprintf(&xpath_running[k_running], "%s/_3gpp-nr-nrm-nrcelldu:NRCellDU[id='ManagedElement=%s,GNBDUFunction=%d,NRCellDu=0']", GNBDU_FUNCTION_XPATH, netconf_config->info.node_id, netconf_config->info.gnb_du_id);
    if(xpath_running[k_running] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    NRCELLDU_XPATH = xpath_running[k_running];
    k_running++;

        values_running[k_running] = strdup("1");
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/priorityLabel", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", netconf_config->info.cell_local_id);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/cellLocalId", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        char sdHex[9];
        sprintf(sdHex, "%06x", oai->nrcelldu.sd);

        sdHex[8] = 0;
        sdHex[7] = sdHex[5];
        sdHex[6] = sdHex[4];
        sdHex[5] = ':';
        sdHex[4] = sdHex[3];
        sdHex[3] = sdHex[2];
        sdHex[2] = ':';

        asprintf(&xpath_running[k_running], "%s/attributes/pLMNInfoList[mcc='%s'][mnc='%s'][sd='%s'][sst='%d']", NRCELLDU_XPATH, oai->nrcelldu.mcc, oai->nrcelldu.mnc, sdHex, oai->nrcelldu.sst);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&xpath_running[k_running], "%s/attributes/nPNIdentityList[idx='%d']", NRCELLDU_XPATH, 0);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        NPNIDENTITYLIST_XPATH = xpath_running[k_running];
        k_running++;

            asprintf(&xpath_running[k_running], "%s/plmnid[mcc='%s'][mnc='%s']", NPNIDENTITYLIST_XPATH, oai->nrcelldu.mcc, oai->nrcelldu.mnc);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            values_running[k_running] = strdup("1");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/cAGIdList", NPNIDENTITYLIST_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

            values_running[k_running] = strdup("1");
            if(values_running[k_running] == 0) {
                log_error("strdup failed");
                goto failure;
            }
            asprintf(&xpath_running[k_running], "%s/nIDList", NPNIDENTITYLIST_XPATH);
            if(xpath_running[k_running] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_running++;

        asprintf(&values_running[k_running], "%d", oai->nrcelldu.nRPCI);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/nRPCI", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->nrcelldu.arfcnDL);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/arfcnDL", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->nrcelldu.arfcnUL);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/arfcnUL", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->nrcelldu.bSChannelBwDL);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/bSChannelBwDL", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->nrcelldu.bSChannelBwUL);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/bSChannelBwUL", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "2023-06-06T00:00:00Z");   //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringStartTime", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "2023-06-06T00:00:00Z");   //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringStopTime", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringWindowDuration", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringWindowStartingOffset", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringWindowPeriodicity", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringOccasionInterval", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/rimRSMonitoringOccasionStartingOffset", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", oai->nrcelldu.ssbFrequency);
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/ssbFrequency", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 5);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/ssbPeriodicity", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 15);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/ssbSubCarrierSpacing", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/ssbOffset", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "%d", 1);  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/ssbDuration", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "Tuf=Jy,H:u=|");  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/nRSectorCarrierRef", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "Tuf=Jy,H:u=|");  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/victimSetRef", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

        asprintf(&values_running[k_running], "Tuf=Jy,H:u=|");  //checkAL
        if(values_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/attributes/aggressorSetRef", NRCELLDU_XPATH);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;
    
    for (int i = start_k_running; i < stop_k_running; i++) {
        if(xpath_running[i]) {
            log("[runn] populating %s with %s.. ", xpath_running[i], values_running[i]);
            rc = sr_set_item_str(netconf_session_running, xpath_running[i], values_running[i], 0, 0);
            if(rc != SR_ERR_OK) {
                log_error("sr_set_item_str failed");
                goto failure;
            }
        }
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    rc = netconf_data_register_callbacks();
    if(rc != 0) {
        log_error("netconf_data_register_callbacks");
        goto failure;
    }

    return 0;

failure:
    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    return 1;
}

int netconf_data_update_alarm(const alarm_t *alarm, int notification_id) {
    int rc = 0;
    char *now = get_netconf_timestamp();
    if(now == 0) {
        log_error("get_netconf_timestamp() error");
        goto failure;
    }

    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    if(alarm == 0) {
        log_error("alarm is null");
        goto failure;
    }

    alarm_t **alarms = (alarm_t **)netconf_alarms;
    int i = 0;
    while(*alarms) {
        if(strcmp(alarm->alarm, (*alarms)->alarm) == 0) {
            break;
        }

        alarms++;
        i++;
    }

    if(*alarms == 0) {
        log_error("alarm not found in list");
        goto failure;
    }

    if(ALARM_XPATH[i] == 0) {
        log_error("ALARM_XPATH not found");
        goto failure;
    }

    // find k_running
    int k_running = 0;
    while(k_running < MAX_XPATH_ENTRIES) {
        if(xpath_running[k_running] == ALARM_XPATH[i]) {
            break;
        }
        k_running++;
    }
    
    if(k_running >= MAX_XPATH_ENTRIES) {
        log_error("ALARM_XPATH[i] not found among running xpaths");
        goto failure;
    }

    int start_k_running = k_running;
    int stop_k_running = k_running;
    while(xpath_running[stop_k_running] && strstr(xpath_running[stop_k_running], ALARM_XPATH[i]) == xpath_running[stop_k_running]) {
        stop_k_running++;
    }

    rc = sr_delete_item(netconf_session_running, ALARM_XPATH[i], SR_EDIT_STRICT);
    if(rc != SR_ERR_OK) {
        log_error("sr_delete_item failure");
        goto failure;
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    for (int i = start_k_running; i < stop_k_running; i++) {
        free(values_running[i]);
        free(xpath_running[i]);
        values_running[i] = 0;
        xpath_running[i] = 0;
    }

    asprintf(&xpath_running[k_running], "%s/attributes/alarmRecords[alarmId='%s-%s']", ALARMLIST_XPATH, alarm->object_instance, alarm->alarm);
    if(xpath_running[k_running] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    ALARM_XPATH[i] = xpath_running[k_running];
    k_running++;

        alarm_severity_t severity = ALARM_SEVERITY_CLEARED;
        if(alarm->state != ALARM_STATE_CLEARED) {
            severity = alarm->severity;
        }

        values_running[k_running] = strdup(alarm_severity_to_str(severity));
        if(values_running[k_running] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_running[k_running], "%s/perceivedSeverity", ALARM_XPATH[i]);
        if(xpath_running[k_running] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_running++;

    stop_k_running = k_running;



    // find k_operational
    int k_operational = 0;
    while(k_operational < MAX_XPATH_ENTRIES) {
        if(xpath_operational[k_operational] == ALARM_XPATH_OPER[i]) {
            break;
        }
        k_operational++;
    }
    
    if(k_operational >= MAX_XPATH_ENTRIES) {
        log_error("ALARM_XPATH_OPER[i] not found among operational xpaths");
        goto failure;
    }

    int start_k_operational = k_operational;
    int stop_k_operational = k_operational;
    while(xpath_operational[stop_k_operational] && strstr(xpath_operational[stop_k_operational], ALARM_XPATH_OPER[i]) == xpath_operational[stop_k_operational]) {
        stop_k_operational++;
    }

    for (int i = start_k_operational; i < stop_k_operational; i++) {
        free(values_operational[i]);
        free(xpath_operational[i]);
        values_operational[i] = 0;
        xpath_operational[i] = 0;
    }

    asprintf(&xpath_operational[k_operational], "%s/attributes/alarmRecords[alarmId='%s-%s']", ALARMLIST_XPATH, alarm->object_instance, alarm->alarm);
    if(xpath_operational[k_operational] == 0) {
        log_error("asprintf failed");
        goto failure;
    }
    ALARM_XPATH_OPER[i] = xpath_operational[k_operational];
    k_operational++;

        values_operational[k_operational] = strdup(alarm->object_instance);
        if(values_operational[k_operational] == 0) {
            log_error("strdup failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/objectInstance", ALARM_XPATH_OPER[i]);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        asprintf(&values_operational[k_operational], "%d", notification_id);
        if(values_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/notificationId", ALARM_XPATH_OPER[i]);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        values_operational[k_operational] = strdup(alarm_type_to_str(alarm->type));
        if(values_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/alarmType", ALARM_XPATH_OPER[i]);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        values_operational[k_operational] = strdup("unset");
        if(values_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/probableCause", ALARM_XPATH_OPER[i]);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        // alarmChangedTime - not set until data is available
        values_operational[k_operational] = strdup(now);
        if(values_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        asprintf(&xpath_operational[k_operational], "%s/alarmChangedTime", ALARM_XPATH_OPER[i]);
        if(xpath_operational[k_operational] == 0) {
            log_error("asprintf failed");
            goto failure;
        }
        k_operational++;

        if(alarm->state == ALARM_STATE_CLEARED) {
            // alarmRaisedTime - not set until data is available
            k_operational++;

            // alarmClearedTime - not set until data is available
            values_operational[k_operational] = strdup(now);
            if(values_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/alarmClearedTime", ALARM_XPATH_OPER[i]);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;
        }
        else {
            // alarmRaisedTime - not set until data is available
            values_operational[k_operational] = strdup(now);
            if(values_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            asprintf(&xpath_operational[k_operational], "%s/alarmRaisedTime", ALARM_XPATH_OPER[i]);
            if(xpath_operational[k_operational] == 0) {
                log_error("asprintf failed");
                goto failure;
            }
            k_operational++;

            // alarmClearedTime - not set until data is available
            k_operational++;
        }

    stop_k_operational = k_operational;




    for (int i = start_k_running; i < stop_k_running; i++) {
        if(xpath_running[i]) {
            log("[runn] populating %s with %s.. ", xpath_running[i], values_running[i]);
            rc = sr_set_item_str(netconf_session_running, xpath_running[i], values_running[i], 0, 0);
            if(rc != SR_ERR_OK) {
                log_error("sr_set_item_str failed");
                goto failure;
            }
        }
    }

    rc = sr_apply_changes(netconf_session_running, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    for (int i = start_k_operational; i < stop_k_operational; i++) {
        if(xpath_operational[i]) {
            log("[oper] populating %s with %s.. ", xpath_operational[i], values_operational[i]);
            rc = sr_set_item_str(netconf_session_operational, xpath_operational[i], values_operational[i], 0, 0);
            if(rc != SR_ERR_OK) {
                log_error("sr_set_item_str failed");
                goto failure;
            }
        }
    }

    rc = sr_apply_changes(netconf_session_operational, 0);
    if(rc != SR_ERR_OK) {
        log_error("sr_apply_changes failed");
        goto failure;
    }

    rc = netconf_data_register_callbacks();
    if(rc != 0) {
        log_error("netconf_data_register_callbacks");
        goto failure;
    }

    free(now);

    return 0;

failure:
    rc = netconf_data_unregister_callbacks();
    if(rc != 0) {
        log_error("netconf_data_unregister_callbacks");
        goto failure;
    }

    free(now);

    return 1;
}


static int netconf_data_register_callbacks() {
    if(MANAGED_ELEMENT_XPATH == 0) {
        log_error("MANAGED_ELEMENT_XPATH is null")
        goto failed;
    }

    if(netconf_data_subscription) {
        log_error("already subscribed")
        goto failed;
    }

    int rc = sr_module_change_subscribe(netconf_session_running, "_3gpp-common-managed-element", MANAGED_ELEMENT_XPATH, netconf_data_edit_callback, NULL, 0, 0, &netconf_data_subscription);
    if (rc != SR_ERR_OK) {
        log_error("sr_module_change_subscribe() failed");
        goto failed;
    }

    return 0;
failed:
    sr_unsubscribe(netconf_data_subscription);

    return 1;
}

static int netconf_data_unregister_callbacks() {
    if(netconf_data_subscription) {
        sr_unsubscribe(netconf_data_subscription);
        netconf_data_subscription = 0;
    }

    return 0;
}

static int netconf_data_edit_callback(sr_session_ctx_t *session, uint32_t sub_id, const char *module_name, const char *xpath_running, sr_event_t event, uint32_t request_id, void *private_data) {
    (void)sub_id;
    (void)request_id;
    (void)private_data;
    
    int rc = SR_ERR_OK;

    sr_change_iter_t *it = 0;
    sr_change_oper_t oper;
    sr_val_t *old_value = 0;
    sr_val_t *new_value = 0;

    char *change_path = 0;

    if(xpath_running) {
        asprintf(&change_path, "%s//.", xpath_running);
    }
    else {
        asprintf(&change_path, "/%s:*//.", module_name);
    }

        
    if(event == SR_EV_CHANGE) {
        rc = sr_get_changes_iter(session, change_path, &it);
        if (rc != SR_ERR_OK) {
            log_error("sr_get_changes_iter() failed");
            goto failed;
        }

        int invalidEdit = 0;
        char *invalidEditReason = 0;
        int bSChannelBwDL = -1;
        int bSChannelBwUL = -1;

        while ((rc = sr_get_change_next(session, it, &oper, &old_value, &new_value)) == SR_ERR_OK) {
            if(oper != SR_OP_MODIFIED) {
                invalidEdit = 1;
                invalidEditReason = strdup("invalid operation (only MODIFY enabled)");
                goto checkInvalidEdit;
            }

            // here we can develop more complete xpath instead of "bSChannelBwDL" if needed
            if(strstr(new_value->xpath, "bSChannelBwDL")) {
                bSChannelBwDL = new_value->data.uint16_val;
            }
            else if(strstr(new_value->xpath, "bSChannelBwUL")) {
                bSChannelBwUL = new_value->data.uint16_val;
            }
            else {
                invalidEdit = 1;
                invalidEditReason = strdup(new_value->xpath);
            }

            sr_free_val(old_value);
            old_value = 0;
            sr_free_val(new_value);
            new_value = 0;

checkInvalidEdit:
            if(invalidEdit) {
                break;
            }
        }

        if(invalidEdit) {
            log_error("invalid edit data detected: %s", invalidEditReason);
            free(invalidEditReason);
            goto failed_validation;
        }

        if((bSChannelBwDL != -1) || (bSChannelBwUL != -1)) {
            if(bSChannelBwDL != bSChannelBwUL) {
                log_error("bSChannelBwDL (%d) != bSChannelBwUL (%d)", bSChannelBwDL, bSChannelBwUL);
                goto failed_validation;
            }
            else {
                // send command
                int rc = telnet_change_bandwidth(bSChannelBwDL);
                if(rc != 0) {
                    log_error("telnet_change_bandwidth failed");
                    goto failed_validation;
                }
            }
        }

        sr_free_change_iter(it);
        it = 0;
    }

    free(change_path);
    if(it) {
        sr_free_change_iter(it);
    }
    if(old_value) {
        sr_free_val(old_value);
    }
    if(new_value) {
        sr_free_val(new_value);
    }

    return SR_ERR_OK;

failed:
    free(change_path);
    if(it) {
        sr_free_change_iter(it);
    }
    if(old_value) {
        sr_free_val(old_value);
    }
    if(new_value) {
        sr_free_val(new_value);
    }

    
    return SR_ERR_INTERNAL;

failed_validation:
    free(change_path);
    if(it) {
        sr_free_change_iter(it);
    }
    if(old_value) {
        sr_free_val(old_value);
    }
    if(new_value) {
        sr_free_val(new_value);
    }
    
    return SR_ERR_VALIDATION_FAILED;
}

