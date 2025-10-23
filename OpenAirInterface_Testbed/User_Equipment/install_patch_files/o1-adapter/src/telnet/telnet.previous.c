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

#include "telnet.h"
#include "common/log.h"

#include <libtelnet.h>
#include <stdio.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <poll.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <termios.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>

static void *telnet_thread_routine(void *arg);
static void thread_routine_sighandler(int signo);
static void telnet_event_handler(telnet_t *telnet, telnet_event_t *ev, void *user_data);
static void telnet_lock();
static void telnet_unlock();
static int telnet_write(const char *s, int timeout, const char **tokens,char **response );

static pthread_t telnet_thread;
static int telnet_sock = -1;
static pthread_mutex_t telnet_mutex;
static pthread_cond_t telnet_cv;
static telnet_t *telnet_telnet;
static char telnet_connect_hostname[129];
static char telnet_connect_port[9];
static int telnet_sendPipe[2];
static int telnet_receivePipe[2];

static telnet_on_event_t telnet_on_connected = 0;
static telnet_on_event_t telnet_on_disconnected = 0;
static telnet_on_event_t telnet_on_closed = 0;
static telnet_on_data_t telnet_on_data = 0;
static telnet_on_data_t telnet_on_data_save;

static const telnet_telopt_t telopts[] = {
	{ TELNET_TELOPT_ECHO,		TELNET_WONT, TELNET_DO   },
	{ TELNET_TELOPT_TTYPE,		TELNET_WILL, TELNET_DONT },
	{ TELNET_TELOPT_COMPRESS2,	TELNET_WONT, TELNET_DO   },
	{ TELNET_TELOPT_MSSP,		TELNET_WONT, TELNET_DO   },
	{ -1, 0, 0 }
};

int telnet_local_init() {
	int rs;

	telnet_telnet = 0;
	telnet_sock = -1;

	rs = pthread_mutex_init(&telnet_mutex, 0);
	if(rs != 0) {
		goto failed;
	}

	rs = pthread_cond_init(&telnet_cv, NULL);
	if(rs != 0) {
		goto failed;
	}

	rs = pipe(telnet_sendPipe);
	if(rs != 0) {
		goto failed;
	}

	rs = pipe(telnet_receivePipe);
	if(rs != 0) {
		goto failed;
	}

	return 0;

failed:
	return 1;
}

int telnet_local_free() {

	pthread_mutex_destroy(&telnet_mutex);

	if(telnet_sendPipe[0] != -1) {
		close(telnet_sendPipe[0]);
	}
	if(telnet_sendPipe[1] != -1) {
		close(telnet_sendPipe[1]);
	}
	if(telnet_receivePipe[0] != -1) {
		close(telnet_receivePipe[0]);
	}
	if(telnet_receivePipe[1] != -1) {
		close(telnet_receivePipe[1]);
	}

	return 0;
}

int telnet_local_connect(const char *hostname, int port) {
	pthread_mutex_lock(&telnet_mutex);

	if(telnet_sock != -1) {
		log_error("telnet already connected");
		goto failed;
	}

	strcpy(telnet_connect_hostname, hostname);
	sprintf(telnet_connect_port, "%d", port);

	/* create server socket */
	if ((telnet_sock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
		log_error("socket() failed: %s\n", strerror(errno));
		goto failed;
	}

	/* create thread */
    if (pthread_create(&telnet_thread, 0, telnet_thread_routine, 0) != 0) {
        log_error("pthread_create() failed");
        goto failed;
    }

	if(pthread_cond_wait(&telnet_cv, &telnet_mutex) != 0) {
		log_error("pthread_cond_wait() failed");
        goto failed;
	}

	if(telnet_sock <= 0) {
		goto failed;
	}

	pthread_mutex_unlock(&telnet_mutex);
	return 0;

failed:

	if(telnet_sock > 0) {
		close(telnet_sock);
		telnet_sock = -1;
	}

	pthread_mutex_unlock(&telnet_mutex);

	return 1;
}

int telnet_local_disconnect() {
	int sock;
	pthread_mutex_lock(&telnet_mutex);
	sock = telnet_sock;
	pthread_mutex_unlock(&telnet_mutex);

	if(sock != -1) {
		// decouple the thread
		pthread_kill(telnet_thread, SIGUSR1);
		pthread_join(telnet_thread, 0);
	}

	return 0;
}

int telnet_local_is_connected() {
	pthread_mutex_lock(&telnet_mutex);
	int result = (telnet_sock != -1);
	pthread_mutex_unlock(&telnet_mutex);

	return result;
}

int telnet_local_register_callback(telnet_on_event_type_t event, telnet_on_event_t callback) {
	pthread_mutex_lock(&telnet_mutex);
	switch(event) {
		case TELNET_ON_CONNECTED:
			telnet_on_connected = callback;
			break;

		case TELNET_ON_DISCONNECTED:
			telnet_on_disconnected = callback;
			break;

		case TELNET_ON_CLOSED:
			telnet_on_closed = callback;
			break;

		case TELNET_ON_DATA:
			telnet_on_data = (telnet_on_data_t)callback;
			break;

		default:
			goto failed;
			break;
	}

	pthread_mutex_unlock(&telnet_mutex);
	return 0;

failed:
	pthread_mutex_unlock(&telnet_mutex);
	return 1;
}

static void *telnet_thread_routine(void *arg) {
    (void)arg;

    log("telnet thread started [%lu]", pthread_self());

	telnet_telnet = 0;

	pthread_mutex_lock(&telnet_mutex);
	struct sockaddr_in addr;
	struct addrinfo *ai = 0;
	struct addrinfo hints;
	int rc;

	/* look up server host */
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	if ((rc = getaddrinfo(telnet_connect_hostname, telnet_connect_port, &hints, &ai)) != 0) {
		log_error("getaddrinfo() failed for %s: %s", telnet_connect_hostname, gai_strerror(rc));
		goto failed;
	}
	
	/* bind server socket */
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	if (bind(telnet_sock, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
		log_error("bind() failed: %s", strerror(errno));
		goto failed;
	}

	/* connect */
	if (connect(telnet_sock, ai->ai_addr, ai->ai_addrlen) == -1) {
		log_error("connect() failed: %s", strerror(errno));
		goto failed;
	}

	freeaddrinfo(ai);


	/* initialize telnet box */
	telnet_telnet = telnet_init(telopts, telnet_event_handler, 0, 0);
	if (telnet_telnet == 0) {
		log_error("telnet_init() failed");
		goto failed;
	}

    struct pollfd pfd[2] = {0};
	pfd[0].fd = telnet_sendPipe[0];
	pfd[0].events = POLLIN;

	pfd[1].fd = telnet_sock;
	pfd[1].events = POLLIN;

    ssize_t rs;
    char buffer[1024];

    struct sigaction sa;
    sa.sa_handler = thread_routine_sighandler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGUSR1, &sa, NULL) == -1) {
        perror("sigaction");
        pthread_exit(NULL);
    }

	if(telnet_on_connected) {
		telnet_on_connected();
	}

	pthread_cond_signal(&telnet_cv);
	pthread_mutex_unlock(&telnet_mutex);

	int closed = 0;

	/* loop while both connections are open */
	while (poll(pfd, 2, -1) != -1) {
        if((pfd[0].revents & POLLNVAL) || (pfd[1].revents & POLLNVAL)) {
			// disconnect event
            break;
        }

		/* read from pipe */    
		if (pfd[0].revents & (POLLIN | POLLERR | POLLHUP)) {
			if ((rs = read(pfd[0].fd, buffer, sizeof(buffer))) > 0) {
                telnet_send(telnet_telnet, buffer, rs);
			} else if (rs == 0) {
				break;
			} else {
				log_error("recv(pipe) failed: %s\n", strerror(errno));
			}
		}

		/* read from client */
		if (pfd[1].revents & (POLLIN | POLLERR | POLLHUP)) {
			rs = recv(telnet_sock, buffer, sizeof(buffer), MSG_DONTWAIT);

			if (rs > 0) {
				telnet_recv(telnet_telnet, buffer, rs);
			} 
			else {
				if (rs < 0) {
					log_error("recv(client) failed: %s\n", strerror(errno));
				}
				
				closed = 1;
				break;
			}
		}
	}

	pthread_mutex_lock(&telnet_mutex);
	if(closed) {
		if(telnet_on_closed) {
			telnet_on_closed();
		}
	}
	else {
		if(telnet_on_disconnected) {
			telnet_on_disconnected();
		}
	}

	if(telnet_sock != -1) {
		close(telnet_sock);
		telnet_sock = -1;
	}

	if(telnet_telnet) {
		telnet_free(telnet_telnet);
	}

	pthread_mutex_unlock(&telnet_mutex);
	log("telnet thread finished [%lu]", pthread_self());

    return (void*)0;

failed:
	freeaddrinfo(ai);

	if(telnet_sock != -1) {
		close(telnet_sock);
		telnet_sock = -1;
	}

	if(telnet_telnet != 0) {
		telnet_free(telnet_telnet);
		telnet_telnet = 0;
	}
	pthread_mutex_unlock(&telnet_mutex);

	log("telnet thread failed [%lu]", pthread_self());

	pthread_cond_signal(&telnet_cv);

	return (void*)0;
}

static void thread_routine_sighandler(int signo) {
    //don't do anything, just need to interrupt poll() in the main loop
}

static void telnet_event_handler(telnet_t *telnet, telnet_event_t *ev, void *user_data) {
	(void)user_data;

	// printf("event: %d\n", ev->type);
	switch (ev->type) {
        /* data received */
        case TELNET_EV_DATA: {
			if(telnet_on_data) {
				char *data = 0;
				asprintf(&data, "%.*s", (int)ev->data.size, ev->data.buffer);
				if(data) {
					telnet_on_data(data);
					free(data);
				}
				else {
					log_error("asprintf() failed");
				}
			}
			else {
				write(telnet_receivePipe[1], ev->data.buffer, ev->data.size);
			}
        } break;
        /* data must be sent */
        case TELNET_EV_SEND: {
            int rs;
            size_t size = ev->data.size;
            const char *buffer = ev->data.buffer;

            /* send data */
            while (size > 0) {
                if ((rs = send(telnet_sock, buffer, size, 0)) == -1) {
                    log_error("send() failed: %s\n", strerror(errno));
                    exit(1);
                } else if (rs == 0) {
                    log_error("send() unexpectedly returned 0\n");
                    exit(1);
                }

                /* update pointer and size to see if we've got more to send */
                buffer += rs;
                size -= rs;
            }
        } break;
        /* request to enable remote feature (or receipt) */
        case TELNET_EV_WILL:
            /* we'll agree to turn off our echo if server wants us to stop */
            // if (ev->neg.telopt == TELNET_TELOPT_ECHO)
            // 	do_echo = 0;
            break;
        /* notification of disabling remote feature (or receipt) */
        case TELNET_EV_WONT:
            // if (ev->neg.telopt == TELNET_TELOPT_ECHO)
            // 	do_echo = 1;
            break;
        /* request to enable local feature (or receipt) */
        case TELNET_EV_DO:
            break;
        /* demand to disable local feature (or receipt) */
        case TELNET_EV_DONT:
            break;
        /* respond to TTYPE commands */
        case TELNET_EV_TTYPE:
            /* respond with our terminal type, if requested */
            if (ev->ttype.cmd == TELNET_TTYPE_SEND) {
                telnet_ttype_is(telnet, getenv("TERM"));
            }
            break;
        /* respond to particular subnegotiations */
        case TELNET_EV_SUBNEGOTIATION:
            break;
        /* error */
        case TELNET_EV_ERROR:
            log_error("ERROR: %s\n", ev->error.msg);
            exit(1);
        
        default:
            /* ignore */
            break;
	}
}

static int telnet_write(const char *s, int timeout, const char **tokens, char **response) {
	if(s == 0) {
		s = "";
	}
	int len = strlen(s);
	int rc;
	char buffer[4096];

	int rlen = 1;
	*response = (char *)realloc(*response, rlen * sizeof(char));
	if(*response == 0) {
		log_error("realloc failed");
		goto failed;
	}
	*response[0] = 0;

	// send out command
	if(len) {
		char *pos = strrchr(s, '\n');
		if(pos == 0) {
			pos = strrchr(s, '\r');
		}

		if(pos) {
			log("telnet_write('%.*s')", (int)(pos-s), s);
		}

		rc = write(telnet_sendPipe[1], s, len);
		if(rc < 0) {
			log_error("telnet write() failed");
			goto failed;
		}
	}

	int found_token = 0;
	long int max_wait = get_seconds_since_epoch() + timeout;
	do {
		if (poll(&(struct pollfd){ .fd = telnet_receivePipe[0], .events = POLLIN }, 1, 1000) == 1) {
			int rs = read(telnet_receivePipe[0], buffer, sizeof(buffer));
			buffer[rs] = 0;

			rlen += rs;
			*response = (char *)realloc(*response, rlen * sizeof(char));
			strcat(*response, buffer);
		}

		found_token = 0;
		if(tokens) {
			const char **token = tokens;
			while(*token) {
				found_token |= (strstr(*response, *token) != 0);
				token++;
			}
		}		
	} while((max_wait >= get_seconds_since_epoch()) && !found_token);
	if(timeout == 0) {
		log_error("telnet_write(%s) timed out", s);
		goto failed;
	}

	return 0;

failed:
	free(*response);
	*response = 0;

	return 1;
}

static void telnet_lock() {
	int wait = 1;
	while(wait) {
		pthread_mutex_lock(&telnet_mutex);
		if(telnet_on_data) {
			telnet_on_data_save = telnet_on_data;
			telnet_on_data = 0;
			wait = 0;
		}
		pthread_mutex_unlock(&telnet_mutex);

		if(wait) {
			sleep(1);
		}
	}
}

static void telnet_unlock() {
	pthread_mutex_lock(&telnet_mutex);
	if((telnet_on_data_save == 0) || (telnet_on_data)) {
		log_error("telnet_unlock() data mismatch");
	}
	telnet_on_data = telnet_on_data_save;
	pthread_mutex_unlock(&telnet_mutex);
}


int telnet_local_wait_for_prompt() {
	char *response = 0;

	telnet_lock();
	const char *tokens[] = {"softmodem_gnb> ", 0};
	int rs = telnet_write(0, 10, tokens, &response);
	if(rs != 0) {
		log_error("telnet_write failed");
		goto failed;
	}
	free(response);
	response = 0;
	telnet_unlock();

	return 0;

failed:
	free(response);
	response = 0;
	telnet_unlock();

	return 1;
}


char *telnet_get_o1_stats() {
	int rs = 0;
	char *response = 0;

	telnet_lock();

	char *start;
	char *stop;

	const char *tokens[] = {"softmodem_gnb> ", 0};
	rs = telnet_write("o1 stats\n", 10, tokens, &response);
	if(rs != 0) {
		log_error("telnet_write failed");
		goto failed;
	}

	start = strchr(response, '{');
	stop = strrchr(response, '}');
	if(stop == 0) {
		goto failed;
	}
	*(stop + 1) = 0;

	char *json = strdup(start);
	free(response);
	response = 0;

	telnet_unlock();
	
	return json;

failed:
	telnet_unlock();

	free(response);
	response = 0;
	return 0;
}

int telnet_change_bandwidth(int new_bandwidth) {
	char *response = 0;
	int rc = 0;
	char buffer[128];

	telnet_lock();

	const char *tokens[] = {"softmodem_gnb> ", 0};
	rc = telnet_write("o1 stop_modem\n", 10, tokens, &response);
	if(rc != 0) {
		log_error("telnet_write failed");
		goto failed;
	}

	if(strstr(response, "FAIL")) {
		log_error("telnet o1 stop_modem failed");
		goto failed;
	}
	free(response);
	response = 0;

	sleep(1);

	sprintf(buffer, "o1 bwconfig %d\n", new_bandwidth);
	rc = telnet_write(buffer, 15, tokens, &response);
	if(rc != 0) {
		log_error("telnet_write failed");
		goto failed;
	}
	
	if(strstr(response, "FAIL")) {
		log_error("telnet o1 bwconfig failed");
		goto failed;
	}
	free(response);
	response = 0;

	sleep(1);

	rc = telnet_write("o1 start_modem\n", 10, tokens, &response);
	if(rc != 0) {
		log_error("telnet_write failed");
		goto failed;
	}

	if(strstr(response, "FAIL")) {
		log_error("telnet o1 start_modem failed");
		goto failed;
	}
	free(response);
	response = 0;

	telnet_unlock();
	
	return 0;

failed:
 	telnet_unlock();
	free(response);
	response = 0;

	return 1;
}
