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

#include <stdio.h>

// own includes
#include "alarms/alarms.h"
#include "common/config.h"
#include "common/log.h"
#include "common/utils.h"
#include "netconf/netconf.h"
#include "netconf/netconf_data.h"
#include "oai/oai.h"
#include "pm_data/pm_data.h"
#include "ves/ves.h"
#include "telnet/telnet.h"

#include <pthread.h>

void telnet_on_data(const char *data) {
    log("telnet has DATA: '%s'", data);
}

int main(int argc, char **argv) {
    int rc = 0;
    config_t *config = 0;

    log_init();
    log("binary size is %lu bytes", get_file_size(argv[0]));
    log("arguments (total: %d): ", argc - 1);
    for(int i = 1; i < argc; i++) {
        log(" - '%s' ", argv[i]);
    }

    log("main thread started [%lu]", pthread_self());

    const char *config_file = "./config/config.json";

    // arguments parsing
    if(argc > 1) {
        log("parsing arguments...");
        for(int i = 1; i < argc; i++) {
            if((strcmp(argv[i], "-c") == 0) || (strcmp(argv[i], "--config") == 0)) {
                if(i + 1 >= argc) {
                    log_error("invalid argument count");
                    goto failure;
                }
                config_file = argv[i + 1];
                i++;

                log("overriding config file from arguments: %s", config_file);
            }
            else if(strcmp(argv[i], "--help") == 0) {
                printf("OAI-NETCONF adapter:\n");
                printf(" --help                         displays help\n");
                printf(" -c/--config [config_file]      changes default config file path\n");
                exit(0);
            }
            else {
                log_error("invalid argument passed: %s", argv[i]);
                goto failure;
            }
        }
    }
    
    // configuration init
    log("initializing config from %s", config_file);
    rc = config_init(config_file);
    if(rc) {
        log_error("config error");
        goto failure;
    }

    config = config_get();
    if(config == 0) {
        log_error("config_get() error");
        goto failure;
    }

    config_print(config);

    log("initializing telnet client...");
    rc = telnet_local_init();
    if(rc) {
        log_error("telnet init error");
        goto failure;
    }

    // setting up telnet for alarms
    telnet_local_register_callback(TELNET_ON_CONNECTED, alarms_on_telnet_connected);
    telnet_local_register_callback(TELNET_ON_DISCONNECTED, alarms_on_telnet_disconnected);
    telnet_local_register_callback(TELNET_ON_CLOSED, alarms_on_telnet_disconnected);
    telnet_local_register_callback(TELNET_ON_DATA, (telnet_on_event_t)telnet_on_data);

    log("initalizing netconf...");
    rc = netconf_init();
    if(rc) {
        log_error("netconf init error");
        goto failure;
    }

    log("initalizing netconf_data...");
    rc = netconf_data_init(config);
    if(rc) {
        log_error("netconf_data init error");
        goto failure;
    }

    log("initalizing pm_data...");
    rc = pm_data_init(config);
    if(rc) {
        log_error("pm_data init error");
        goto failure;
    }

    log("initalizing ves...");
    rc = ves_init(config);
    if(rc) {
        log_error("ves init error");
        goto failure;
    }

    log("initalizing alarms...");
    rc = alarms_init(config);
    if(rc) {
        log_error("alarms init error");
        goto failure;
    }

    log("initializing oai...");
    rc = oai_init();
    if(rc) {
        log_error("oai_init error");
        goto failure;
    }

    log("starting main loop");
    while(1) {
        // check telnet connection
        if(!telnet_local_is_connected()) {
            log("telnet connecting...");
            if(telnet_local_connect(config->telnet.host, config->telnet.port) == 0) {
                if(telnet_local_wait_for_prompt() != 0) {
                    log_error("telnet prompt failure");
                    telnet_local_disconnect();
                }
            }
        }

        if(telnet_local_is_connected()) do {
            char *json = telnet_get_o1_stats();
            if(json == 0) {
                log_error("telnet_get_o1_stats() failed")
                break;
            }
            oai_data_t *oai_data = oai_data_parse_json(json);
            free(json);
            if(oai_data == 0) {
                log_error("oai_data_parse_json() failed")
                break;
            }

            rc = oai_data_feed(oai_data);
            if(rc != 0) {
                log_error("oai_data_feed() error");
                break;
            }

            if(oai_data) {
                oai_data_free(oai_data);
            }
        } while(0);

        alarms_loop();
        pm_data_loop();
        ves_loop();

        fflush(stdout);
        sleep(1);
    }

    log("freeing oai...");
    oai_free();

    log("freeing alarms...");
    alarms_free();

    log("freeing ves...");
    ves_free();

    log("freeing pm_data...");
    pm_data_free();

    log("freeing netconf_data...");
    netconf_data_free();

    log("freeing netconf...");
    netconf_free();

    log("freeing telnet...");
    telnet_local_free();

    log("freeing config...");
    config_free(config);

    log("OAI-NETCONF clean finish...");
    log("main thread finished [%lu]", pthread_self());

    return 0;

failure:
    config_free(config);
    log_error("exiting with failure");
    log("main thread failed [%lu]", pthread_self());
    return 1;
}