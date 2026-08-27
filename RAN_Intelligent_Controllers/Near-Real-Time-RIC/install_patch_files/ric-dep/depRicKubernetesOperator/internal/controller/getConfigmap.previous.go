package controller

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func GetConfigMap() []*corev1.ConfigMap {

	configMap1 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-a1mediator-a1conf",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"local.rt": "newrt|start\n" +
				"# Warning! this is not a functioning table because the subscription manager and route manager are now involved in a1 flows\n" +
				"# the real routing table requires subscription ids as routing is now done over sub ids, but this isn't known until xapp deploy time, it's a dynamic process triggered by the xapp manager\n" +
				"# there is a single message type for all messages a1 sends out now, subid is the other necessary piece of info\n" +
				"# there are two message types a1 listens for; 20011 (instance response) and 20012 (query)\n" +
				"# xapps likely use rts to reply with 20012 so the routing entry isn't needed for that in most cases\n" +
				"mse|20010|SUBID|service-ricxapp-admctrl-rmr.ricxapp:4563\n" +
				"rte|20011|service-ricplt-a1mediator-rmr.ricplt:4562\n" +
				"rte|20012|service-ricplt-a1mediator-rmr.ricplt:4562\n" +
				"newrt|end\n" +
				"",
			"loglevel.txt": "log-level:",
		},
	}

	configMap2 := &corev1.ConfigMap{
		Data: map[string]string{
			"CONFIG_MAP_NAME":             "/opt/route/loglevel.txt",
			"INSTANCE_DELETE_NO_RESP_TTL": "5",
			"INSTANCE_DELETE_RESP_TTL":    "10",
			"PYTHONUNBUFFERED":            "1",
			"RMR_RTG_SVC":                 "4561",
			"RMR_SRC_ID":                  "service-ricplt-a1mediator-rmr.ricplt",
			"A1_RMR_RETRY_TIMES":          "20",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-a1mediator-env",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap3 := &corev1.ConfigMap{
		Data: map[string]string{
			"ALARM_MGR_SERVICE_NAME": "service-ricplt-alarmmanager-rmr.ricplt",
			"ALARM_MGR_SERVICE_PORT": "4560",
		},
		ObjectMeta: metav1.ObjectMeta{
			Namespace: "ricplt",
			Name:      "configmap-ricplt-alarmmanager-appconfig",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap4 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "alarm-appconfig",
			Namespace: "ricxapp",
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
		Data: map[string]string{
			"ALARM_MGR_SERVICE_NAME": "service-ricplt-alarmmanager-rmr.ricplt",
			"ALARM_MGR_SERVICE_PORT": "4560",
		},
	}

	configMap5 := &corev1.ConfigMap{
		Data: map[string]string{
			"alarmmanagercfg": "{  \n" +
				"  \"local\": {\n" +
				"    \"host\": \":8080\"\n" +
				"  },\n" +
				"  \"logger\": {\n" +
				"    \"level\": 4\n" +
				"  },\n" +
				"  \"db\": {\n" +
				"    \"namespaces\": [\"sdl\", \"rnib\"]\n" +
				"  },\n" +
				"  \"rmr\": {\n" +
				"    \"protPort\": \"tcp:4560\",\n" +
				"    \"maxSize\": 1024,\n" +
				"    \"numWorkers\": 1\n" +
				"  },\n" +
				"  \"controls\": {\n" +
				"    \"promAlertManager\": {\n" +
				"      \"address\": \"cpro-alertmanager:80\",\n" +
				"      \"baseUrl\": \"api/v2\",\n" +
				"      \"schemes\": \"http\",\n" +
				"      \"alertInterval\": 30000\n" +
				"    },\n" +
				"    \"maxActiveAlarms\": 5000,\n" +
				"    \"maxAlarmHistory\": 20000,\n" +
				"    \"alarmInfoPvFile\": \"/mnt/pv-ricplt-alarmmanager/alarminfo.json\"\n" +
				"  }\n" +
				"}",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-alarmmanager-alarmmanagercfg",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap6 := &corev1.ConfigMap{
		Data: map[string]string{
			"RMR_SEED_RT": "/cfg/uta_rtg.rt",
			"RMR_SRC_ID":  "service-ricplt-alarmmanager-rmr.ricplt",
			"RMR_RTG_SVC": "service-ricplt-rtmgr-rmr:4561",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-alarmmanager-env",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap7 := &corev1.ConfigMap{
		Data: map[string]string{
			"appmgr.yaml": "\"local\":\n" +
				"  # Port on which the xapp-manager REST services are provided\n" +
				"  \"host\": \":8080\"\n" +
				"\"helm\":\n" +
				"  # Remote helm repo URL. UPDATE this as required.\n" +
				"  \"repo\": \"\\\"http://service-ricplt-xapp-onboarder-http:8080\\\"\"\n" +
				"\n" +
				"  # Repo name referred within the xapp-manager\n" +
				"  \"repo-name\": \"helm-repo\"\n" +
				"\n" +
				"  # Tiller service details in the cluster. UPDATE this as required.\n" +
				"  \"tiller-service\": service-tiller-ricxapp\n" +
				"  \"tiller-namespace\": ricinfra\n" +
				"  \"tiller-port\": \"44134\"\n" +
				"  # helm username and password files\n" +
				"  \"helm-username-file\": \"/opt/ric/secret/helm_repo_username\"\n" +
				"  \"helm-password-file\": \"/opt/ric/secret/helm_repo_password\"\n" +
				"  \"retry\": 1\n" +
				"\"xapp\":\n" +
				"  #Namespace to install xAPPs\n" +
				"  \"namespace\": \"ricxapp\"\n" +
				"  \"tarDir\": \"/tmp\"\n" +
				"  \"schema\": \"descriptors/schema.json\"\n" +
				"  \"config\": \"config/config-file.json\"\n" +
				"  \"tmpConfig\": \"/tmp/config-file.json\"\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-appmgr-appconfig",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap8 := &corev1.ConfigMap{
		Data: map[string]string{
			"appmgr-tiller-secret-copier.sh": "#!/bin/sh\n" +
				"if [ -x /svcacct-to-kubeconfig.sh ] ; then\n" +
				" /svcacct-to-kubeconfig.sh\n" +
				"fi\n" +
				"\n" +
				"if [ ! -z \"${HELM_TLS_CA_CERT}\" ]; then\n" +
				"  kubectl -n ${SECRET_NAMESPACE} get secret -o yaml ${SECRET_NAME} | \\\n" +
				"   grep 'ca.crt:' | \\\n" +
				"   awk '{print $2}' | \\\n" +
				"   base64 -d > ${HELM_TLS_CA_CERT}\n" +
				"fi\n" +
				"\n" +
				"if [ ! -z \"${HELM_TLS_CERT}\" ]; then\n" +
				"  kubectl -n ${SECRET_NAMESPACE} get secret -o yaml ${SECRET_NAME} | \\\n" +
				"   grep 'tls.crt:' | \\\n" +
				"   awk '{print $2}' | \\\n" +
				"   base64 -d > ${HELM_TLS_CERT}\n" +
				"fi\n" +
				"\n" +
				"if [ ! -z \"${HELM_TLS_KEY}\" ]; then\n" +
				"  kubectl -n ${SECRET_NAMESPACE} get secret -o yaml ${SECRET_NAME} | \\\n" +
				"   grep 'tls.key:' | \\\n" +
				"   awk '{print $2}' | \\\n" +
				"   base64 -d > ${HELM_TLS_KEY}\n" +
				"fi\n" +
				"",
			"svcacct-to-kubeconfig.sh": "#!/bin/sh\n" +
				"\n" +
				"# generate a kubconfig (at ${KUBECONFIG} file from the automatically-mounted\n" +
				"# service account token.\n" +
				"# ENVIRONMENT:\n" +
				"# SVCACCT_NAME: the name of the service account user.  default \"default\"\n" +
				"# CLUSTER_NAME: the name of the kubernetes cluster.  default \"kubernetes\"\n" +
				"# KUBECONFIG: where the generated file will be deposited.\n" +
				"SVCACCT_TOKEN=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`\n" +
				"CLUSTER_CA=`base64 /var/run/secrets/kubernetes.io/serviceaccount/ca.crt|tr -d '\\n'`\n" +
				"\n" +
				"cat >${KUBECONFIG} <<__EOF__\n" +
				"ApiVersion: v1\n" +
				"kind: Config\n" +
				"users:\n" +
				"- name: ${SVCACCT_NAME:-default}\n" +
				"  user:\n" +
				"    token: ${SVCACCT_TOKEN}\n" +
				"clusters:\n" +
				"- cluster:\n" +
				"    certificate-authority-data: ${CLUSTER_CA}\n" +
				"    server: ${K8S_API_HOST:-https://kubernetes.default.svc.cluster.local/}\n" +
				"  name: ${CLUSTER_NAME:-kubernetes}\n" +
				"contexts:\n" +
				"- context:\n" +
				"    cluster: ${CLUSTER_NAME:-kubernetes}\n" +
				"    user: ${SVCACCT_NAME:-default}\n" +
				"  name: svcs-acct-context\n" +
				"current-context: svcs-acct-context\n" +
				"__EOF__\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-appmgr-bin",
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
	}

	configMap9 := &corev1.ConfigMap{
		Data: map[string]string{
			"RMR_RTG_SVC":       "4561",
			"HELM_TLS_CA_CERT":  "/opt/ric/secret/tiller-ca.cert",
			"HELM_TLS_CERT":     "/opt/ric/secret/helm-client.cert",
			"HELM_TLS_HOSTNAME": "service-tiller-ricxapp",
			"HELM_TLS_VERIFY":   "true",
			"NAME":              "xappmgr",
			"HELM_HOST":         "service-tiller-ricxapp.ricinfra:44134",
			"HELM_TLS_ENABLED":  "true",
			"HELM_TLS_KEY":      "/opt/ric/secret/helm-client.key",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-appmgr-env",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap10 := &corev1.ConfigMap{
		Data: map[string]string{
			"DBAAS_NODE_COUNT":   "1",
			"DBAAS_SERVICE_HOST": "service-ricplt-dbaas-tcp.ricplt",
			"DBAAS_SERVICE_PORT": "6379",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-dbaas-appconfig",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap11 := &corev1.ConfigMap{
		Data: map[string]string{
			"DBAAS_NODE_COUNT":   "1",
			"DBAAS_SERVICE_HOST": "service-ricplt-dbaas-tcp.ricplt",
			"DBAAS_SERVICE_PORT": "6379",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "dbaas-appconfig",
			Namespace: "ricxapp",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap12 := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"redis.conf": "dir \"/data\"\n" +
				"appendonly no\n" +
				"bind 0.0.0.0\n" +
				"loadmodule /usr/local/libexec/redismodule/libredismodule.so\n" +
				"protected-mode no\n" +
				"save\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Namespace: "ricplt",
			Labels: map[string]string{
				"app":      "ricplt-dbaas",
				"chart":    "dbaas-2.0.0",
				"heritage": "Helm",
				"release":  "release-name",
			},
			Name: "configmap-ricplt-dbaas-config",
		},
	}

	configMap13 := &corev1.ConfigMap{
		Data: map[string]string{
			"rmr_verbose": "0\n" +
				"",
			"router.txt": "newrt|start\n" +
				"rte|1080|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|1090|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|1100|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|1101|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|1200|service-ricplt-rsm-rmr.ricplt:4801\n" +
				"rte|1210|service-ricplt-rsm-rmr.ricplt:4801\n" +
				"rte|1220|service-ricplt-rsm-rmr.ricplt:4801\n" +
				"rte|10020|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10060|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|10061|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10062|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10070|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|10071|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|10080|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10360|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|10361|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10362|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10370|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10371|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|12010|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|12020|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"rte|20001|service-ricplt-a1mediator-rmr.ricplt:4562\n" +
				"newrt|end",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-e2mgr-router-configmap",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap14 := &corev1.ConfigMap{
		Data: map[string]string{
			"configuration.yaml": "logging:\n" +
				"  logLevel:  \"info\"     \n" +
				"http:\n" +
				"  port: 3800\n" +
				"rmr:\n" +
				"  port: 3801\n" +
				"  maxMsgSize: 65536\n" +
				"\n" +
				"routingManager:\n" +
				"  baseUrl: \"http://service-ricplt-rtmgr-http:3800/ric/v1/handles/\"\n" +
				"notificationResponseBuffer: 100\n" +
				"bigRedButtonTimeoutSec: 5 \n" +
				"maxConnectionAttempts: 3 \n" +
				"maxRnibConnectionAttempts: 3 \n" +
				"rnibRetryIntervalMs: 10\n" +
				"keepAliveResponseTimeoutMs: 360000\n" +
				"keepAliveDelayMs: 120000\n" +
				"\n" +
				"globalRicId:\n" +
				"  ricId: \"AACCE\"\n" +
				"  mcc: \"310\"\n" +
				"  mnc: \"411\"\n" +
				"  \n" +
				"rnibWriter:\n" +
				"  stateChangeMessageChannel: \"RAN_CONNECTION_STATUS_CHANGE\"\n" +
				"  ranManipulationMessageChannel: \"RAN_MANIPULATION\"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-e2mgr-configuration-configmap",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap15 := &corev1.ConfigMap{
		Data: map[string]string{
			"logcfg": "loglevel: 3",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-e2mgr-loglevel-configmap",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap16 := &corev1.ConfigMap{
		Data: map[string]string{
			"RMR_RTG_SVC": "4561",
			"RMR_SRC_ID":  "service-ricplt-e2mgr-rmr.ricplt",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-e2mgr-env",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap17 := &corev1.ConfigMap{
		Data: map[string]string{
			"log-level": "log-level: 3",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-e2term-loglevel-configmap",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap18 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-e2term-router-configmap",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"rmr_verbose": "0\n" +
				"",
			"router.txt": "newrt|start\n" +
				"rte|1080|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|1090|service-ricplt-e2term-rmr-alpha.ricplt:38000\n" +
				"rte|1100|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10020|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10060|service-ricplt-e2term-rmr-alpha.ricplt:38000\n" +
				"rte|10061|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10062|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10030|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10070|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10071|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10080|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10091|service-ricplt-rsm-rmr.ricplt:4801\n" +
				"rte|10092|service-ricplt-rsm-rmr.ricplt:4801\n" +
				"rte|10360|service-ricplt-e2term-rmr-alpha.ricplt:38000\n" +
				"rte|10361|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10362|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10370|service-ricplt-e2mgr-rmr.ricplt:3801\n" +
				"rte|10371|service-ricplt-e2term-rmr-alpha.ricplt:38000\n" +
				"rte|12010|service-ricplt-e2term-rmr-alpha.ricplt:38000\n" +
				"rte|12020|service-ricplt-e2term-rmr-alpha.ricplt:38000\n" +
				"rte|20001|service-ricplt-a1mediator-rmr.ricplt:4562\n" +
				"rte|12011|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12050|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12012|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12021|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12022|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12041|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12042|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|12050|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"rte|20000|service-ricxapp-ueec-rmr.ricxapp:4560;service-admission-ctrl-xapp-rmr.ricxapp:4560\n" +
				"newrt|end",
		},
	}

	configMap19 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-e2term-env-alpha",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"RMR_SEED_RT":   "router.txt",
			"RMR_SRC_ID":    "service-ricplt-e2term-rmr-alpha.ricplt",
			"RMR_VCTL_FILE": "/tmp/rmr_verbose",
			"nano":          "38000",
			"print":         "1",
			"sctp":          "36422",
			"volume":        "/data/outgoing/",
			"RMR_RTG_SVC":   "4561",
		},
	}

	configMap20 := &corev1.ConfigMap{
		Data: map[string]string{
			"servers.conf": "# Prometheus metrics and health-checking server\n" +
				"server {\n" +
				"    server_name kong_prometheus_exporter;\n" +
				"    listen 0.0.0.0:9542; # can be any other port as well\n" +
				"    access_log off;\n" +
				"    location /status {\n" +
				"        default_type text/plain;\n" +
				"        return 200;\n" +
				"    }\n" +
				"    location /metrics {\n" +
				"        default_type text/plain;\n" +
				"        content_by_lua_block {\n" +
				"             local prometheus = require \"kong.plugins.prometheus.exporter\"\n" +
				"             prometheus:collect()\n" +
				"        }\n" +
				"    }\n" +
				"    location /nginx_status {\n" +
				"        internal;\n" +
				"        access_log off;\n" +
				"        stub_status;\n" +
				"    }\n" +
				"}\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Labels: map[string]string{
				"app.kubernetes.io/name":       "kong",
				"app.kubernetes.io/version":    "1.4",
				"helm.sh/chart":                "kong-0.36.6",
				"app.kubernetes.io/instance":   "release-name",
				"app.kubernetes.io/managed-by": "Helm",
			},
			Name: "release-name-kong-default-custom-server-blocks",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap21 := &corev1.ConfigMap{
		Data: map[string]string{
			"TRACING_JAEGER_LOG_LEVEL":     "error",
			"TRACING_JAEGER_SAMPLER_PARAM": "1",
			"TRACING_JAEGER_SAMPLER_TYPE":  "const",
			"TRACING_ENABLED":              "0",
			"TRACING_JAEGER_AGENT_ADDR":    "service-ricplt-jaegeradapter-agent.ricplt",
		},
		ObjectMeta: metav1.ObjectMeta{
			Namespace: "ricplt",
			Name:      "configmap-ricplt-jaegeradapter",
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
	}

	configMap22 := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"servers.conf": "# Prometheus metrics and health-checking server\n" +
				"server {\n" +
				"    server_name kong_prometheus_exporter;\n" +
				"    listen 0.0.0.0:9542; # can be any other port as well\n" +
				"    access_log off;\n" +
				"    location /status {\n" +
				"        default_type text/plain;\n" +
				"        return 200;\n" +
				"    }\n" +
				"    location /metrics {\n" +
				"        default_type text/plain;\n" +
				"        content_by_lua_block {\n" +
				"             local prometheus = require \"kong.plugins.prometheus.exporter\"\n" +
				"             prometheus:collect()\n" +
				"        }\n" +
				"    }\n" +
				"    location /nginx_status {\n" +
				"        internal;\n" +
				"        access_log off;\n" +
				"        stub_status;\n" +
				"    }\n" +
				"}\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Labels: map[string]string{
				"app.kubernetes.io/version":    "1.4",
				"helm.sh/chart":                "kong-0.36.6",
				"app.kubernetes.io/instance":   "release-name",
				"app.kubernetes.io/managed-by": "Helm",
				"app.kubernetes.io/name":       "kong",
			},
			Name: "release-name-kong-default-custom-server-blocks",
		},
	}

	configMap23 := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"config-file.json": "{\n" +
				"    \"local\": {\n" +
				"        \"host\": \":8080\"\n" +
				"    },\n" +
				"    \"logger\": {\n" +
				"        \"level\": 4\n" +
				"    },\n" +
				"    \"db\": {\n" +
				"        \"namespaces\": [\"sdl\", \"rnib\"]\n" +
				"    },\n" +
				"    \"rmr\": {\n" +
				"        \"protPort\": \"tcp:4560\",\n" +
				"        \"maxSize\": 65536,\n" +
				"        \"numWorkers\": 1\n" +
				"    },\n" +
				"    \"sbi\": {\n" +
				"        \"appmgrAddr\": \"service-ricplt-appmgr-http:8080\",\n" +
				"        \"alertmgrAddr\": \"r4-infrastructure-prometheus-alertmanager:80\",\n" +
				"        \"timeout\": 30\n" +
				"    },\n" +
				"    \"nbi\": {\n" +
				"        \"schemas\": [\"o-ran-sc-ric-xapp-desc-v1\", \"o-ran-sc-ric-ueec-config-v1\"]\n" +
				"    },\n" +
				"    \"controls\": {\n" +
				"        \"active\": true\n" +
				"    }\n" +
				"}\n" +
				"\n" +
				"",
			"uta_rtg.rt": "newrt|start\n" +
				"rte|13111|127.0.0.1:4588\n" +
				"rte|13111|127.0.0.1:4560\n" +
				"newrt|end\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-o1mediator-appconfig-configmap",
			Namespace: "ricplt",
		},
	}

	configMap24 := &corev1.ConfigMap{
		Data: map[string]string{
			"RMR_SEED_RT": "/etc/o1agent/uta_rtg.rt",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-o1mediator-env",
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
	}

	configMap25 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Labels: map[string]string{
				"chart":     "prometheus-11.3.0",
				"component": "alertmanager",
				"heritage":  "Helm",
				"release":   "release-name",
				"app":       "prometheus",
			},
			Name:      "release-name-prometheus-alertmanager",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"alertmanager.yml": "global:\n" +
				"  resolve_timeout: 5m\n" +
				"receivers:\n" +
				"- name: vespa\n" +
				"  webhook_configs:\n" +
				"  - url: http://service-ricplt-vespamgr-http:9095/alerts\n" +
				"route:\n" +
				"  group_by:\n" +
				"  - alertname\n" +
				"  - severity\n" +
				"  - instance\n" +
				"  - job\n" +
				"  group_interval: 3m\n" +
				"  group_wait: 5s\n" +
				"  receiver: vespa\n" +
				"  repeat_interval: 1h\n" +
				"  routes:\n" +
				"  - continue: true\n" +
				"    receiver: vespa\n" +
				"",
		},
	}

	configMap26 := &corev1.ConfigMap{
		Data: map[string]string{
			"alerting_rules.yml": "{}\n" +
				"",
			"alerts": "{}\n" +
				"",
			"prometheus.yml": "global:\n" +
				"  evaluation_interval: 1m\n" +
				"  scrape_interval: 1m\n" +
				"  scrape_timeout: 10s\n" +
				"rule_files:\n" +
				"- /etc/config/recording_rules.yml\n" +
				"- /etc/config/alerting_rules.yml\n" +
				"- /etc/config/rules\n" +
				"- /etc/config/alerts\n" +
				"scrape_configs:\n" +
				"- job_name: prometheus\n" +
				"  static_configs:\n" +
				"  - targets:\n" +
				"    - localhost:9090\n" +
				"- bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n" +
				"  job_name: kubernetes-apiservers\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: endpoints\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: default;kubernetes;https\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_namespace\n" +
				"    - __meta_kubernetes_service_name\n" +
				"    - __meta_kubernetes_endpoint_port_name\n" +
				"  scheme: https\n" +
				"  tls_config:\n" +
				"    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt\n" +
				"    insecure_skip_verify: true\n" +
				"- bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n" +
				"  job_name: kubernetes-nodes\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: node\n" +
				"  relabel_configs:\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_node_label_(.+)\n" +
				"  - replacement: kubernetes.default.svc:443\n" +
				"    target_label: __address__\n" +
				"  - regex: (.+)\n" +
				"    replacement: /api/v1/nodes/$1/proxy/metrics\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_node_name\n" +
				"    target_label: __metrics_path__\n" +
				"  scheme: https\n" +
				"  tls_config:\n" +
				"    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt\n" +
				"    insecure_skip_verify: true\n" +
				"- bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n" +
				"  job_name: kubernetes-nodes-cadvisor\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: node\n" +
				"  relabel_configs:\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_node_label_(.+)\n" +
				"  - replacement: kubernetes.default.svc:443\n" +
				"    target_label: __address__\n" +
				"  - regex: (.+)\n" +
				"    replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_node_name\n" +
				"    target_label: __metrics_path__\n" +
				"  scheme: https\n" +
				"  tls_config:\n" +
				"    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt\n" +
				"    insecure_skip_verify: true\n" +
				"- job_name: kubernetes-service-endpoints\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: endpoints\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: true\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_scrape\n" +
				"  - action: replace\n" +
				"    regex: (https?)\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_scheme\n" +
				"    target_label: __scheme__\n" +
				"  - action: replace\n" +
				"    regex: (.+)\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_path\n" +
				"    target_label: __metrics_path__\n" +
				"  - action: replace\n" +
				"    regex: ([^:]+)(?::\\d+)?;(\\d+)\n" +
				"    replacement: $1:$2\n" +
				"    source_labels:\n" +
				"    - __address__\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_port\n" +
				"    target_label: __address__\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_service_label_(.+)\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_namespace\n" +
				"    target_label: kubernetes_namespace\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_name\n" +
				"    target_label: kubernetes_name\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_node_name\n" +
				"    target_label: kubernetes_node\n" +
				"- job_name: kubernetes-service-endpoints-slow\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: endpoints\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: true\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_scrape_slow\n" +
				"  - action: replace\n" +
				"    regex: (https?)\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_scheme\n" +
				"    target_label: __scheme__\n" +
				"  - action: replace\n" +
				"    regex: (.+)\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_path\n" +
				"    target_label: __metrics_path__\n" +
				"  - action: replace\n" +
				"    regex: ([^:]+)(?::\\d+)?;(\\d+)\n" +
				"    replacement: $1:$2\n" +
				"    source_labels:\n" +
				"    - __address__\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_port\n" +
				"    target_label: __address__\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_service_label_(.+)\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_namespace\n" +
				"    target_label: kubernetes_namespace\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_name\n" +
				"    target_label: kubernetes_name\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_node_name\n" +
				"    target_label: kubernetes_node\n" +
				"  scrape_interval: 5m\n" +
				"  scrape_timeout: 30s\n" +
				"- honor_labels: true\n" +
				"  job_name: prometheus-pushgateway\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: service\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: pushgateway\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_probe\n" +
				"- job_name: kubernetes-services\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: service\n" +
				"  metrics_path: /probe\n" +
				"  params:\n" +
				"    module:\n" +
				"    - http_2xx\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: true\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_service_annotation_prometheus_io_probe\n" +
				"  - source_labels:\n" +
				"    - __address__\n" +
				"    target_label: __param_target\n" +
				"  - replacement: blackbox\n" +
				"    target_label: __address__\n" +
				"  - source_labels:\n" +
				"    - __param_target\n" +
				"    target_label: instance\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_service_label_(.+)\n" +
				"  - source_labels:\n" +
				"    - __meta_kubernetes_namespace\n" +
				"    target_label: kubernetes_namespace\n" +
				"  - source_labels:\n" +
				"    - __meta_kubernetes_service_name\n" +
				"    target_label: kubernetes_name\n" +
				"- job_name: kubernetes-pods\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: pod\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: true\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_annotation_prometheus_io_scrape\n" +
				"  - action: replace\n" +
				"    regex: (.+)\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_annotation_prometheus_io_path\n" +
				"    target_label: __metrics_path__\n" +
				"  - action: replace\n" +
				"    regex: ([^:]+)(?::\\d+)?;(\\d+)\n" +
				"    replacement: $1:$2\n" +
				"    source_labels:\n" +
				"    - __address__\n" +
				"    - __meta_kubernetes_pod_annotation_prometheus_io_port\n" +
				"    target_label: __address__\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_pod_label_(.+)\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_namespace\n" +
				"    target_label: kubernetes_namespace\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_name\n" +
				"    target_label: kubernetes_pod_name\n" +
				"- job_name: kubernetes-pods-slow\n" +
				"  kubernetes_sd_configs:\n" +
				"  - role: pod\n" +
				"  relabel_configs:\n" +
				"  - action: keep\n" +
				"    regex: true\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_annotation_prometheus_io_scrape_slow\n" +
				"  - action: replace\n" +
				"    regex: (.+)\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_annotation_prometheus_io_path\n" +
				"    target_label: __metrics_path__\n" +
				"  - action: replace\n" +
				"    regex: ([^:]+)(?::\\d+)?;(\\d+)\n" +
				"    replacement: $1:$2\n" +
				"    source_labels:\n" +
				"    - __address__\n" +
				"    - __meta_kubernetes_pod_annotation_prometheus_io_port\n" +
				"    target_label: __address__\n" +
				"  - action: labelmap\n" +
				"    regex: __meta_kubernetes_pod_label_(.+)\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_namespace\n" +
				"    target_label: kubernetes_namespace\n" +
				"  - action: replace\n" +
				"    source_labels:\n" +
				"    - __meta_kubernetes_pod_name\n" +
				"    target_label: kubernetes_pod_name\n" +
				"  scrape_interval: 5m\n" +
				"  scrape_timeout: 30s\n" +
				"alerting:\n" +
				"  alertmanagers:\n" +
				"  - kubernetes_sd_configs:\n" +
				"      - role: pod\n" +
				"    tls_config:\n" +
				"      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt\n" +
				"    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n" +
				"    relabel_configs:\n" +
				"    - source_labels: [__meta_kubernetes_namespace]\n" +
				"      regex: ricplt\n" +
				"      action: keep\n" +
				"    - source_labels: [__meta_kubernetes_pod_label_app]\n" +
				"      regex: prometheus\n" +
				"      action: keep\n" +
				"    - source_labels: [__meta_kubernetes_pod_label_component]\n" +
				"      regex: alertmanager\n" +
				"      action: keep\n" +
				"    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_probe]\n" +
				"      regex: .*\n" +
				"      action: keep\n" +
				"    - source_labels: [__meta_kubernetes_pod_container_port_number]\n" +
				"      regex:\n" +
				"      action: drop\n" +
				"",
			"recording_rules.yml": "{}\n" +
				"",
			"rules": "{}\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Namespace: "ricplt",
			Labels: map[string]string{
				"chart":     "prometheus-11.3.0",
				"component": "server",
				"heritage":  "Helm",
				"release":   "release-name",
				"app":       "prometheus",
			},
			Name: "release-name-prometheus-server",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap27 := &corev1.ConfigMap{
		Data: map[string]string{
			"update-node.sh": "#!/bin/sh\n" +
				"REDIS_NODES=\"/data/nodes.conf\"\n" +
				"sed -i -e \"/myself/ s/[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}/${POD_IP}/\" ${REDIS_NODES}\n" +
				"exec \"$@\"\n" +
				"",
			"redis.conf": "cluster-enabled yes\n" +
				"cluster-require-full-coverage no\n" +
				"cluster-node-timeout 15000\n" +
				"cluster-config-file /data/nodes.conf\n" +
				"cluster-migration-barrier 1\n" +
				"appendonly yes\n" +
				"protected-mode no",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "redis-cluster-cm",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap28 := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
		Data: map[string]string{
			"placenode.pl": "#!/usr/bin/env perl\n" +
				"=head\n" +
				"============LICENSE_START=======================================================\n" +
				"\n" +
				"================================================================================\n" +
				"Copyright (C) 2020 Hcl Technologies Limited.\n" +
				"================================================================================\n" +
				"Licensed under the Apache License, Version 2.0 (the \"License\");\n" +
				"you may not use this file except in compliance with the License.\n" +
				"You may obtain a copy of the License at\n" +
				"\n" +
				"     http://www.apache.org/licenses/LICENSE-2.0\n" +
				"\n" +
				"Unless required by applicable law or agreed to in writing, software\n" +
				"distributed under the License is distributed on an \"AS IS\" BASIS,\n" +
				"WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n" +
				"See the License for the specific language governing permissions and\n" +
				"limitations under the License.\n" +
				"============LICENSE_END=========================================================\n" +
				"\n" +
				"\n" +
				"About:\n" +
				"\n" +
				"This script has been developed as part of https://jira.o-ran-sc.org/browse/RIC-360\n" +
				"This script identifies the missing anti-affinity(as per above ticket) of redis instances \n" +
				"required in a redis-cluster. If there is an  undesired  anti-affinity this script can  be \n" +
				"executed to communicate to redis nodes  to switch roles (e.g. master/slave) such that the \n" +
				"end-state meets the desired anti-affinity.\n" +
				"       \n" +
				"\n" +
				"Pre-requisites: \n" +
				"\n" +
				"  1) A redis cluster with 3 masters (2 replicas each) deployed on kubernetes 1.18 (or later) \n" +
				"  2) Three available worker nodes for serving redis workloads\n" +
				"  3) kubectl (with access to the k8 cluster)\n" +
				"\n" +
				"=cut\n" +
				"\n" +
				"\n" +
				"my $podRow = { \n" +
				"\"podIP\"      => \"\",\n" +
				"\"podName\"    => \"\",\n" +
				"\"k8Node\"     => \"\",\n" +
				"\n" +
				"\"rdNodeRole\" => \"\",\n" +
				"\"rdNodeID\"   => \"\",\n" +
				"\n" +
				"\"rdMasterNodeID\"   => \"\",\n" +
				"\"slaveIPs\"    => [] \n" +
				"};\n" +
				"\n" +
				"# Pod label for redis nodes\n" +
				"my $podLabel = $ENV{'POD_LABEL'};\n" +
				"\n" +
				"my $podTable =   [];\n" +
				"my $k8NodeInfo = [];\n" +
				"\n" +
				"setk8NodesInfo();\n" +
				"validate();\n" +
				"\n" +
				"# Master\n" +
				"spreadMastersIfRequired();\n" +
				"# Slave\n" +
				"my $disparity = getSlaveDisparity();\n" +
				"spreadSlavesIfRequired();\n" +
				"\n" +
				"sub validate() {\n" +
				"    my @masters = map { $_->{'rdNodeRole'} eq 'master' ? $_ : () } @{$podTable};\n" +
				"	if ( @masters > @{$k8NodeInfo->{allk8Nodes}} ) {\n" +
				"		print \"Info: Skipping any action as num of master > number of k8 nodes..\\n\";\n" +
				"	    exit;\n" +
				"	}\n" +
				"}\n" +
				"\n" +
				"\n" +
				"sub spreadSlavesIfRequired() {\n" +
				"    \n" +
				"\n" +
				"	# Get node with maximum disparity first\n" +
				"    my @disparityMatrix = reverse sort { @{$a} <=> @{$b} } @${disparity}; \n" +
				"    #@disparityMatrix = grep defined, @disparityMatrix;\n" +
				"    #@disparityMatrix = map { defined $_ ? $_ : () } @disparityMatrix;\n" +
				"\n" +
				"    # Get list of slaves to be swapped roles.\n" +
				"    my @slaveSwapList = ();\n" +
				"    my $maxDisparityPerNode = @{$disparityMatrix[0]};\n" +
				"\n" +
				"    for (my $disparityPass=0; $disparityPass < $maxDisparityPerNode; $disparityPass++) {\n" +
				"        for (my $k8NodeIndex=0; $k8NodeIndex <= $#{disparityMatrix}; $k8NodeIndex++) {\n" +
				"		   #print \"$disparityMatrix[$disparityPass] && $disparityMatrix[$k8NodeIndex][$disparityPass]\";\n" +
				"           if ( $disparityMatrix[$disparityPass] && $disparityMatrix[$k8NodeIndex][$disparityPass] ) {\n" +
				"			    push(@slaveSwapList,$disparityMatrix[$k8NodeIndex][$disparityPass]);\n" +
				"		   }\n" +
				"        }\n" +
				"    }\n" +
				"    if ( ! @slaveSwapList ) {\n" +
				"    	print \"Info: No disparity found with slaves.\\n\" if ( @slaveSwapList < 2);\n" +
				"		exit;\n" +
				"	} elsif ( @slaveSwapList == 1 ) {\n" +
				"     	print \"Info: single host scenario (with no swap candidate in other k8 nodes) found.\\n\";\n" +
				"		exit;\n" +
				"	} else {\n" +
				"    	print \"Info: slave disparity found.\\n\";\n" +
				"    }\n" +
				"\n" +
				"	# Swap slaves \n" +
				"	for (my $swapIndex=0; $swapIndex < @slaveSwapList; $swapIndex++) {\n" +
				"		$pod1 = $slaveSwapList[$swapIndex];\n" +
				"		$pod2 = $slaveSwapList[++$swapIndex];\n" +
				"		#print \"Info: Swapping Slaves: \" . join($pod1->{podName}, $pod2->{podName}) . \"\\n\";\n" +
				"		\n" +
				"		my $cmd1 = qq[kubectl exec -it ].\n" +
				"		  		   qq[$pod1->{podName}  -- redis-cli -p 6379 cluster replicate $pod2->{rdMasterNodeID} ];\n" +
				"		\n" +
				"		my $cmd2 = qq[kubectl exec -it ].\n" +
				"				   qq[$pod2->{podName}  -- redis-cli -p 6379 cluster replicate $pod1->{rdMasterNodeID} ];\n" +
				"\n" +
				"	    runRediClusterCmd($cmd1);\n" +
				"	    runRediClusterCmd($cmd2);\n" +
				"		#print \"\\n$cmd1\";\n" +
				"		#print \"\\n$cmd2\\n\";\n" +
				"    }\n" +
				"\n" +
				"}\n" +
				"\n" +
				"\n" +
				"sub getSlaveDisparity() {\n" +
				"\n" +
				"    # Get Slave Disparity Metrix\n" +
				"    my $disparity = ();\n" +
				"    my $nodeIndex = 0;\n" +
				"    foreach my $k8NodeName ( @{$k8NodeInfo->{allk8Nodes}} ) {\n" +
				"        my @redisNodesOnk8Node = map { $_->{'k8Node'} eq $k8NodeName ? $_ : () } @{$podTable};\n" +
				"        @redisNodesOnk8Node    = sort { $a->{\"rdNodeRole\"} cmp $b->{\"rdNodeRole\"} } @redisNodesOnk8Node;\n" +
				"\n" +
				"        my $master = shift @redisNodesOnk8Node;\n" +
				"        \n" +
				"        for (my $index=0; $index <= $#{redisNodesOnk8Node}; $index++ ) {\n" +
				"            my $slave = $redisNodesOnk8Node[$index];\n" +
				"            #print \"chekcing for pod:  $slave->{podName}\\n\";\n" +
				"            my $disparityFound = 0;\n" +
				"            if ( $slave->{rdMasterNodeID} eq $master->{rdNodeID} ) {\n" +
				"               $disparityFound = 1;\n" +
				"            } else {\n" +
				"               #check is other slaves are its sibling\n" +
				"               for (my $nextIndex=$index + 1; $nextIndex <= $#{redisNodesOnk8Node}; $nextIndex++ ) {\n" +
				"                   if ( $slave->{rdMasterNodeID} eq $redisNodesOnk8Node[$nextIndex]->{rdMasterNodeID} ) {\n" +
				"                          $disparityFound = 1;\n" +
				"                       break;\n" +
				"                   }\n" +
				"               }\n" +
				"            }\n" +
				"			if ($disparityFound) {\n" +
				"            	#$disparity[$nodeIndex][$index] = { 'podName' => $slave->{\"podName\"}, 'rdMasterNodeID' => $slave->{\"rdMasterNodeID\"} } ;\n" +
				"            	push(@{$disparity[$nodeIndex]},{ 'podName' => $slave->{\"podName\"}, 'rdMasterNodeID' => $slave->{\"rdMasterNodeID\"} } ) ;\n" +
				"			}\n" +
				"        }\n" +
				"        $nodeIndex++;\n" +
				"    }\n" +
				"        return \\@disparity;\n" +
				"}\n" +
				"\n" +
				"sub spreadMastersIfRequired() {\n" +
				"\n" +
				"   NODE_WITH_NO_MASTER: foreach my $nodeWithoutMaster (@{$k8NodeInfo->{k8NodesWithoutMaster}}) {\n" +
				"      # For each k8Node without any master \n" +
				"      #    Check for each extra master on its hostNode\n" +
				"      #        Find its slave on the this hostNode (i.e. without any master) \n" +
				"      # Such slave must be Found for 3x3 set-up:\n" +
				"      # Then Promote as master # Re-Evaluate\n" +
				"\n" +
				"      # Get All Redis Slaves on This k8 node\n" +
				"      print \"Info: K8 node without any master : $nodeWithoutMaster\\n\";\n" +
				"      my @rdSlaveNodes =  map { ($_->{'k8Node'} eq $nodeWithoutMaster ) && ($_->{'rdNodeRole'} eq 'slave') ? $_ : () } @{$podTable};\n" +
				"\n" +
				"           foreach my $nodeWithExtraMaster (@{$k8NodeInfo->{k8NodesWithExtraMaster}} ) {\n" +
				"              print \"Info: k8 Node with extra master : $nodeWithExtraMaster\\n\";\n" +
				"              #my @rdSlaveNodes =  map { ($_->{'k8Node'} eq $nodeWithoutMaster ) && ($_->{'rdNodeRole'} eq 'slave') ? $_ : () } @{$podTable};\n" +
				"\n" +
				"              my @masterInstances = map { ($_->{'k8Node'} eq $nodeWithExtraMaster ) && ($_->{'rdNodeRole'} eq 'master') ? $_ : () } @{$podTable};        \n" +
				"              foreach my $master (@masterInstances) {\n" +
				"                  my @slave = map { $_->{\"rdMasterNodeID\"} eq $master->{rdNodeID} ? $_ : () } @rdSlaveNodes;\n" +
				"                  if ( @slave ) {\n" +
				"                      promoteSlaveAsMaster($slave[0]);\n" +
				"					  my $isPromoted = 0;\n" +
				"				      my $slaveNodeID= $slave[0]->{rdNodeID};\n" +
				"					  while( ! $isPromoted ) {\n" +
				"						 sleep(8);\n" +
				"					     setk8NodesInfo();\n" +
				"						 my ($promotedNode) = map { $slaveNodeID eq $_->{rdNodeID} ? $_ : () } @{$podTable};\n" +
				"\n" +
				"						 if ( $promotedNode->{'rdNodeRole'} ne 'master' ) {\n" +
				"						 	print (\"Info: Waiting for node promotion confirmation..\\n\");\n" +
				"						 } else {\n" +
				"							$isPromoted = 1;\n" +
				"						 	print (\"Info: Node promotion confirmed.\\n\");\n" +
				"						 }\n" +
				"					  }\n" +
				"                      next NODE_WITH_NO_MASTER;\n" +
				"                  }\n" +
				"              }\n" +
				"           }\n" +
				"   }\n" +
				"   print \"Info: All redis masters are on separate k8 Nodes. \\n\"    if ( ! @{$k8NodeInfo->{k8NodesWithoutMaster}}) ;\n" +
				"}\n" +
				"\n" +
				"sub promoteSlaveAsMaster() {\n" +
				"    my $slavePod = shift;    \n" +
				"    #print \"Info: Promoting Slave $slavePod->{'podName'} On $slavePod->{'k8Node'} as master\";\n" +
				"    my $cmd = qq[kubectl exec -it $slavePod->{'podName'} -- redis-cli -p 6379 cluster failover takeover];\n" +
				"    runRediClusterCmd($cmd);\n" +
				"    \n" +
				"}\n" +
				"sub runRediClusterCmd() {\n" +
				"  my $cmd = shift;    \n" +
				"  print \"Info: Running Cmd:$cmd \\n\";\n" +
				"  `$cmd;`;\n" +
				"  sleep(8);\n" +
				"}\n" +
				"\n" +
				"\n" +
				"#foreach my $item (@{$podTable}) {\n" +
				"#}\n" +
				"\n" +
				"# find_nodes_without-a-single_master\n" +
				"sub setk8NodesInfo() {\n" +
				"\n" +
				"   $podTable   = [];\n" +
				"   $k8NodeInfo = [];\n" +
				"\n" +
				"   getCurrentStatus();\n" +
				"   # All k8 nodes\n" +
				"   my @k8NodeList = uniq(map { $_->{'k8Node'} } @$podTable);\n" +
				"\n" +
				"   # Find Nodes with At least One master\n" +
				"   my @k8NodesWithMaster;\n" +
				"   foreach my $nodeName (@k8NodeList) {\n" +
				"      push(@k8NodesWithMaster, map { ($_->{'k8Node'} eq $nodeName) && ($_->{'rdNodeRole'} eq 'master')   ? $nodeName : ()  } @{$podTable} );\n" +
				"   }\n" +
				"\n" +
				"   # Find Nodes without any master = All nodes - Nodes with at least one Master\n" +
				"   my %k8NodesMap = ();\n" +
				"   foreach (@k8NodesWithMaster) { \n" +
				"           if ( exists $k8NodesMap{$_} ) {\n" +
				"                   $k8NodesMap{$_}++;\n" +
				"           } else {\n" +
				"                   $k8NodesMap{$_} = 1;\n" +
				"           }\n" +
				"   }\n" +
				"   my @k8NodesWithoutMaster = map { exists $k8NodesMap{$_} ? () : $_ } @k8NodeList;\n" +
				"   my @k8NodesWithExtraMaster = uniq(map { $k8NodesMap{$_} > 1 ? $_ : () } @k8NodesWithMaster);\n" +
				"\n" +
				"   $k8NodeInfo = { 'allk8Nodes' => \\@k8NodeList, 'k8NodesWithExtraMaster' => \\@k8NodesWithExtraMaster, 'k8NodesWithoutMaster' => \\@k8NodesWithoutMaster };\n" +
				"}\n" +
				"\n" +
				"\n" +
				"\n" +
				"\n" +
				"\n" +
				"# Validate if number of masters ,= number of rea\n" +
				"\n" +
				"#\n" +
				"#sub filter\n" +
				"\n" +
				"=head\n" +
				"get \n" +
				"podName where k8Node eq \"x\"\n" +
				"    get position of k8node eq x \n" +
				"where \n" +
				"=cut\n" +
				"\n" +
				"exit;\n" +
				"\n" +
				"sub uniq {\n" +
				"    my %seen;\n" +
				"    grep !$seen{$_}++, @_;\n" +
				"}\n" +
				"\n" +
				"sub getCurrentStatus() {\n" +
				"\n" +
				"    # Run pod list command    \n" +
				"    my @getPods = `kubectl get po --no-headers  -o wide -l $podLabel |grep Running`;    chomp @getPods;\n" +
				"    #my @getPods = `kubectl get po --no-headers  -o wide -l managed-by=redis-cluster-operator|grep Running`;    chomp @getPods;\n" +
				"\n" +
				"    foreach my $podLine (@getPods) {\n" +
				"        my @podData = split(/\\s+/,$podLine);\n" +
				"        my ($podName,$status,$age,$podIP,$podNode) = ($podData[0], $podData[2], $podData[4], $podData[5],$podData[6]);\n" +
				"\n" +
				"        #print \"$podName,$status,$age,$podIP,$podNode\" .\"\\n\"; \n" +
				"        my $podRow = { 'podIP' => $podIP, 'podName' => $podName, 'k8Node' => $podNode, 'podAge' => $age, 'podStatus' => $status };    \n" +
				"        push (@{$podTable},$podRow)\n" +
				"    }\n" +
				"\n" +
				"    my $podName = $podTable->[0]{'podName'};\n" +
				"    #print \"Info:kubectl exec $podName  -- cat nodes.conf|sort -k3\\n\";\n" +
				"    my @rdNodeData = `kubectl exec $podName  -- cat nodes.conf|sort -k3`;    chomp @rdNodeData;\n" +
				"    foreach my $rdNodeLine (@rdNodeData) {\n" +
				"        next if ($rdNodeLine !~ /master|slave/);\n" +
				"            my @rdNodeData = split(/\\s+/,$rdNodeLine);\n" +
				"            my ($rdNodeID,$rdRole,$rdMasterNodeID,$epoch) = ($rdNodeData[0], $rdNodeData[2], $rdNodeData[3],$rdNodeData[5]);\n" +
				"            my ($podIP) = split(/:/,$rdNodeData[1]);\n" +
				"            $rdRole =~ s/myself,//;\n" +
				"\n" +
				"            #print \"$rdNodeID,$rdRole,$rdMasterNodeID,$podIP\" .\"\\n\";\n" +
				"            my $rdElem = { 'podIP'    => $podIP, \n" +
				"                           'rdNodeID' => $rdNodeID,\n" +
				"                           'rdRole'   => $rdRole,\n" +
				"                           'rdMasterNodeID' => $rdMasterNodeID,\n" +
				"                           'epoch'          => $epoch\n" +
				"            };\n" +
				"\n" +
				"        for(my $index=0; $index <= $#{$podTable}; $index++) {\n" +
				"            if ( $podTable->[$index]{'podIP'} eq $podIP ) {\n" +
				"                #print \"Matched\\n\";\n" +
				"                $podTable->[$index]{'rdNodeID'}       = $rdNodeID;\n" +
				"                $podTable->[$index]{'rdNodeRole'}        = $rdRole;\n" +
				"                $podTable->[$index]{'rdMasterNodeID'} = $rdMasterNodeID;\n" +
				"                $podTable->[$index]{'epoch'}          = $epoch;\n" +
				"            }\n" +
				"        }\n" +
				"        #exit;\n" +
				"\n" +
				"    }\n" +
				"}\n" +
				"",
			"relatenode.sh": "#!/bin/sh\n" +
				"podLabel=${POD_LABEL}\n" +
				"firstPod=$(kubectl  get   po -o wide -l app.kubernetes.io/name=redis-cluster --no-headers=true|head -1|cut -d\" \" -f1)\n" +
				"\n" +
				"kubectl get po -o wide -l $podLabel |tail +2|awk '{printf(\"%s:%s:%s:%s\\n\",$6,$1,$7,$10)}'|sort  > /tmp/1.txt\n" +
				"kubectl exec  $firstPod  -- cat nodes.conf|sed 's/myself,//'|awk '/master|slave/ {print $2,$1,$3,$4}'|sort > /tmp/2.txt\n" +
				"join -t \":\"  /tmp/1.txt /tmp/2.txt |sort -k3,4 | sed 's/ /:/g'|awk -F\":\" '{print $2,$7,$3,$1,$4,$6,$8}' > /tmp/3.txt\n" +
				"\n" +
				"echo \"\\n   POD_NAME      ROLE      k8NODE        POD_IP                   REDIS_NODE_ID                       REDIS_MASTER_NODE_ID\"\n" +
				"grep $(cut -d\" \" -f4 /tmp/2.txt|sort -u|grep -v \"-\"|sed -n '1p') /tmp/3.txt\n" +
				"echo \"\"\n" +
				"grep $(cut -d\" \" -f4 /tmp/2.txt|sort -u|grep -v \"-\"|sed -n '2p') /tmp/3.txt\n" +
				"echo \"\"\n" +
				"grep $(cut -d\" \" -f4 /tmp/2.txt|sort -u|grep -v \"-\"|sed -n '3p') /tmp/3.txt",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "assigner-cm",
		},
	}

	configMap29 := &corev1.ConfigMap{
		Data: map[string]string{
			"rmr_verbose": "0\n" +
				"",
			"router.txt": "newrt|start\n" +
				"rte|10090|service-ricplt-e2term-rmr.ricplt:38000\n" +
				"newrt|end",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-rsm-router-configmap",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap30 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-rsm",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"configuration.yaml": "logging:\n" +
				"  logLevel:  \"info\"\n" +
				"http:\n" +
				"  port: 4800\n" +
				"rmr:\n" +
				"  port: 4801\n" +
				"  maxMsgSize: 4096\n" +
				"  readyIntervalSec: 1\n" +
				"rnib:\n" +
				"  maxRnibConnectionAttempts: 3\n" +
				"  rnibRetryIntervalMs: 10",
		},
	}

	configMap31 := &corev1.ConfigMap{
		Data: map[string]string{
			"RMR_RTG_SVC": "4561",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-rsm-env",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap32 := &corev1.ConfigMap{
		Data: map[string]string{
			"rtmgrcfg": "\"PlatformComponents\":\n" +
				"  -\n" +
				"    \"name\": \"SUBMAN\"\n" +
				"    \"fqdn\": \"service-ricplt-submgr-rmr.ricplt\"\n" +
				"    \"port\": 4560\n" +
				"  -\n" +
				"    \"name\": \"E2MAN\"\n" +
				"    \"fqdn\": \"service-ricplt-e2mgr-rmr.ricplt\"\n" +
				"    \"port\": 3801\n" +
				"  -\n" +
				"    \"name\": \"A1MEDIATOR\"\n" +
				"    \"fqdn\": \"service-ricplt-a1mediator-rmr.ricplt\"\n" +
				"    \"port\": 4562\n" +
				"\n" +
				"\"XMURL\":\n" +
				"  \"http://service-ricplt-appmgr-http:8080/ric/v1/xapps\"\n" +
				"\"E2MURL\":\n" +
				"  \"http://service-ricplt-e2mgr-http:3800/v1/e2t/list\"\n" +
				"\"RTFILE\":\n" +
				"  \"/db/rt.json\"\n" +
				"\"CFGFILE\":\n" +
				"  \"/cfg/rtmgr-config.yaml\"\n" +
				"\"RPE\":\n" +
				"  \"rmrpush\"\n" +
				"\"SBI\":\n" +
				"  \"rmrpush\"\n" +
				"\"SBIURL\":\n" +
				"  \"0.0.0.0\"\n" +
				"\"NBI\":\n" +
				"  \"httpRESTful\"\n" +
				"\"NBIURL\":\n" +
				"  \"http://service-ricplt-rtmgr-http:3800\"\n" +
				"\"SDL\":\n" +
				"  \"file\"\n" +
				"\"local\":\n" +
				"  \"host\": \":8080\"\n" +
				"\"logger\":\n" +
				"  \"level\": 4\n" +
				"\"periodicRoutes\":\n" +
				"  \"enable\"		   \n" +
				"\"rmr\":\n" +
				"  \"protPort\": \"tcp:4560\"\n" +
				"  \"maxSize\": 1024\n" +
				"  \"numWorkers\": 1\n" +
				"  \"threadType\": 1\n" +
				"\"messagetypes\": [\n" +
				"   \"RIC_HEALTH_CHECK_REQ=100\",\n" +
				"   \"RIC_HEALTH_CHECK_RESP=101\",\n" +
				"   \"RIC_ALARM=110\",\n" +
				"   \"RIC_ALARM_QUERY=111\",\n" +
				"   \"RIC_SCTP_CONNECTION_FAILURE=1080\",\n" +
				"   \"E2_TERM_INIT=1100\",\n" +
				"   \"E2_TERM_KEEP_ALIVE_REQ=1101\",\n" +
				"   \"E2_TERM_KEEP_ALIVE_RESP=1102\",\n" +
				"   \"RIC_SCTP_CLEAR_ALL=1090\",\n" +
				"   \"RAN_CONNECTED=1200\",\n" +
				"   \"RAN_RESTARTED=1210\",\n" +
				"   \"RAN_RECONFIGURED=1220\",\n" +
				"   \"RIC_ENB_LOAD_INFORMATION=10020\",\n" +
				"   \"RIC_SN_STATUS_TRANSFER=10040\",\n" +
				"   \"RIC_UE_CONTEXT_RELEASE=10050\",\n" +
				"   \"RIC_X2_SETUP_REQ=10060\",\n" +
				"   \"RIC_X2_SETUP_RESP=10061\",\n" +
				"   \"RIC_X2_SETUP_FAILURE=10062\",\n" +
				"   \"RIC_X2_RESET=10070\",\n" +
				"   \"RIC_X2_RESET_RESP=10071\",\n" +
				"   \"RIC_ENB_CONF_UPDATE=10080\",\n" +
				"   \"RIC_ENB_CONF_UPDATE_ACK=10081\",\n" +
				"   \"RIC_ENB_CONF_UPDATE_FAILURE=10082\",\n" +
				"   \"RIC_RES_STATUS_REQ=10090\",\n" +
				"   \"RIC_RES_STATUS_RESP=10091\",\n" +
				"   \"RIC_RES_STATUS_FAILURE=10092\",\n" +
				"   \"RIC_SGNB_ADDITION_REQ=10270\",\n" +
				"   \"RIC_SGNB_ADDITION_ACK=10271\",\n" +
				"   \"RIC_SGNB_ADDITION_REJECT=10272\",\n" +
				"   \"RIC_SGNB_RECONF_COMPLETE=10280\",\n" +
				"   \"RIC_SGNB_MOD_REQUEST=10290\",\n" +
				"   \"RIC_SGNB_MOD_REQUEST_ACK=10291\",\n" +
				"   \"RIC_SGNB_MOD_REQUEST_REJ=10292\",\n" +
				"   \"RIC_SGNB_MOD_REQUIRED=10300\",\n" +
				"   \"RIC_SGNB_MOD_CONFIRM=10301\",\n" +
				"   \"RIC_SGNB_MOD_REFUSE=10302\",\n" +
				"   \"RIC_SGNB_RELEASE_REQUEST=10310\",\n" +
				"   \"RIC_SGNB_RELEASE_REQUEST_ACK=10311\",\n" +
				"   \"RIC_SGNB_RELEASE_REQUIRED=10320\",\n" +
				"   \"RIC_SGNB_RELEASE_CONFIRM=10321\",\n" +
				"   \"RIC_RRC_TRANSFER=10350\",\n" +
				"   \"RIC_ENDC_X2_SETUP_REQ=10360\",\n" +
				"   \"RIC_ENDC_X2_SETUP_RESP=10361\",\n" +
				"   \"RIC_ENDC_X2_SETUP_FAILURE=10362\",\n" +
				"   \"RIC_ENDC_CONF_UPDATE=10370\",\n" +
				"   \"RIC_ENDC_CONF_UPDATE_ACK=10371\",\n" +
				"   \"RIC_ENDC_CONF_UPDATE_FAILURE=10372\",\n" +
				"   \"RIC_SECONDARY_RAT_DATA_USAGE_REPORT=10380\",\n" +
				"   \"RIC_E2_SETUP_REQ=12001\",\n" +
				"   \"RIC_E2_SETUP_RESP=12002\",\n" +
				"   \"RIC_E2_SETUP_FAILURE=12003\",\n" +
				"   \"RIC_ERROR_INDICATION=12007\",\n" +
				"   \"RIC_SUB_REQ=12010\",\n" +
				"   \"RIC_SUB_RESP=12011\",\n" +
				"   \"RIC_SUB_FAILURE=12012\",\n" +
				"   \"RIC_SUB_DEL_REQ=12020\",\n" +
				"   \"RIC_SUB_DEL_RESP=12021\",\n" +
				"   \"RIC_SUB_DEL_FAILURE=12022\",\n" +
				"   \"RIC_SUB_DEL_REQUIRED=12023\",\n" +
				"   \"RIC_CONTROL_REQ=12040\",\n" +
				"   \"RIC_CONTROL_ACK=12041\",\n" +
				"   \"RIC_CONTROL_FAILURE=12042\",\n" +
				"   \"RIC_INDICATION=12050\",\n" +
				"   \"A1_POLICY_REQ=20010\",\n" +
				"   \"A1_POLICY_RESP=20011\",\n" +
				"   \"A1_POLICY_QUERY=20012\",\n" +
				"   \"TS_UE_LIST=30000\",\n" +
				"   \"TS_QOE_PRED_REQ=30001\",\n" +
				"   \"TS_QOE_PREDICTION=30002\",\n" +
				"   \"TS_ANOMALY_UPDATE=30003\",\n" +
				"   \"TS_ANOMALY_ACK=30004\",\n" +
				"   \"MC_REPORT=30010\",\n" +
				"   \"DCAPTERM_RTPM_RMR_MSGTYPE=33001\",\n" +
				"   \"DCAPTERM_GEO_RMR_MSGTYPE=33002\",\n" +
				"   \"RIC_SERVICE_UPDATE=12030\",\n" +
				"   \"RIC_SERVICE_UPDATE_ACK=12031\",\n" +
				"   \"RIC_SERVICE_UPDATE_FAILURE=12032\",\n" +
				"   \"RIC_E2NODE_CONFIG_UPDATE=12070\",\n" +
				"   \"RIC_E2NODE_CONFIG_UPDATE_ACK==12071\",\n" +
				"   \"RIC_E2NODE_CONFIG_UPDATE_FAILURE=12072\",\n" +
				"   \"RIC_E2_RESET_REQ=12004\",\n" +
				"   \"RIC_E2_RESET_RESP=12005\",\n" +
				"   ]\n" +
				"\n" +
				"\"PlatformRoutes\": [\n" +
				"  { 'messagetype': 'RIC_SUB_REQ', 'senderendpoint': 'SUBMAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_SUB_DEL_REQ', 'senderendpoint': 'SUBMAN', 'subscriptionid': -1,'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_SUB_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'SUBMAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_SUB_DEL_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'SUBMAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_SUB_FAILURE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'SUBMAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_SUB_DEL_FAILURE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'SUBMAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_SUB_DEL_REQUIRED', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'SUBMAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_X2_SETUP_REQ', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_X2_RESET', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_X2_RESET_RESP', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_ENDC_X2_SETUP_REQ', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_ENB_CONF_UPDATE_ACK', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_ENB_CONF_UPDATE_FAILURE', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_ENDC_CONF_UPDATE_ACK', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_ENDC_CONF_UPDATE_FAILURE', 'senderendpoint': 'E2MAN', 'subscriptionid': -1, 'endpoint': '', 'meid': '%meid'},\n" +
				"  { 'messagetype': 'RIC_E2_SETUP_REQ', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'E2_TERM_INIT', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_X2_SETUP_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_X2_SETUP_FAILURE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_X2_RESET', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_X2_RESET_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_ENDC_X2_SETUP_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_ENDC_X2_SETUP_FAILURE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_ENDC_CONF_UPDATE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_SCTP_CONNECTION_FAILURE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_ERROR_INDICATION', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_ENB_CONF_UPDATE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_ENB_LOAD_INFORMATION', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'E2_TERM_KEEP_ALIVE_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'A1_POLICY_QUERY', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'A1MEDIATOR', 'meid': ''},\n" +
				"  { 'messagetype': 'A1_POLICY_RESP', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'A1MEDIATOR', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_SERVICE_UPDATE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_E2NODE_CONFIG_UPDATE', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"  { 'messagetype': 'RIC_E2_RESET_REQ', 'senderendpoint': '', 'subscriptionid': -1, 'endpoint': 'E2MAN', 'meid': ''},\n" +
				"   ]\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-rtmgr-rtmgrcfg",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	configMap33 := &corev1.ConfigMap{
		Data: map[string]string{
			"CFGFILE":     "/cfg/rtmgr-config.yaml",
			"RMR_RTG_SVC": "4561",
			"RMR_SEED_RT": "/uta_rtg_ric.rt",
			"RMR_SRC_ID":  "service-ricplt-rtmgr-rmr.ricplt",
			"XMURL":       "http://service-ricplt-appmgr-http:8080/ric/v1/xapps",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-rtmgr-env",
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
	}

	configMap34 := &corev1.ConfigMap{
		Data: map[string]string{
			"submgrcfg": "\"local\":\n" +
				"  \"host\": \":8080\"\n" +
				"\"logger\":\n" +
				"  \"level\": 3\n" +
				"\"rmr\":\n" +
				"  \"protPort\" : \"tcp:4560\"\n" +
				"  \"maxSize\": 8192\n" +
				"  \"numWorkers\": 1\n" +
				"\"rtmgr\":\n" +
				"  \"hostAddr\": \"service-ricplt-rtmgr-http\"\n" +
				"  \"port\"    : 3800\n" +
				"  \"baseUrl\" : \"/ric/v1\"\n" +
				"\"db\":\n" +
				"  \"sessionNamespace\": \"XMSession\"\n" +
				"  \"host\": \":6379\"\n" +
				"  \"prot\": \"tcp\"\n" +
				"  \"maxIdle\": 80\n" +
				"  \"maxActive\": 12000\n" +
				"\"controls\":\n" +
				"  \"e2tSubReqTimeout_ms\": 2000\n" +
				"  \"e2tSubDelReqTime_ms\": 2000\n" +
				"  \"e2tRecvMsgTimeout_ms\": 2000\n" +
				"  \"e2tMaxSubReqTryCount\": 2\n" +
				"  \"e2tMaxSubDelReqTryCount\": 2\n" +
				"  \"checkE2State\": \"true\"\n" +
				"  \"readSubsFromDb\": \"true\"\n" +
				"  \"dbTryCount\": 200\n" +
				"  \"dbRetryForever\": \"true\"\n" +
				"  \"waitRouteCleanup_ms\": 5000\n" +
				"",
			"submgrutartg": "newrt|start\n" +
				"newrt|end\n" +
				"",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "submgrcfg",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
	}

	configMap35 := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"SUBMGR_SEED_SN": "1",
			"CFG_FILE":       "/cfg/submgr-config.yaml",
			"RMR_RTG_SVC":    "4561",
			"RMR_SEED_RT":    "/cfg/submgr-uta-rtg.rt",
			"RMR_SRC_ID":     "service-ricplt-submgr-rmr.ricplt",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-submgr-env",
		},
	}

	configMap36 := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "configmap-ricplt-vespamgr",
			Namespace: "ricplt",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"VESMGR_PRICOLLECTOR_SECURE":     "false",
			"VESMGR_PRICOLLECTOR_SERVERROOT": "/vescollector",
			"VESMGR_ALERTMANAGER_BIND_ADDR":  ":9095",
			"VESMGR_PRICOLLECTOR_PASSWORD":   "sample1",
			"VESMGR_PRICOLLECTOR_ADDR":       "aux-entry",
			"VESMGR_PRICOLLECTOR_PORT":       "8443",
			"VESMGR_PRICOLLECTOR_USER":       "sample1",
			"VESMGR_PROMETHEUS_ADDR":         "http://r4-infrastructure-prometheus-server.ricplt",
			"VESMGR_HB_INTERVAL":             "60s",
			"VESMGR_MEAS_INTERVAL":           "30s",
		},
	}

	configMap37 := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		Data: map[string]string{
			"DEBUG":                 "true",
			"PORT":                  "8080",
			"STORAGE":               "local",
			"STORAGE_LOCAL_ROOTDIR": "/charts",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-xapp-onboarder-chartmuseum-env",
		},
	}

	configMap38 := &corev1.ConfigMap{
		Data: map[string]string{
			"CHART_REPO_URL":               "http://0.0.0.0:8080",
			"CHART_WORKSPACE_PATH":         "/tmp/xapp-onboarder",
			"HTTP_RETRY":                   "3",
			"MOCK_TEST_HELM_REPO_TEMP_DIR": "/tmp/mock_helm_repo",
			"ALLOW_REDEPLOY":               "True",
			"CHART_WORKSPACE_SIZE":         "500MB",
			"FLASK_DEBUG":                  "False",
			"FLASK_PORT":                   "8888",
			"HELM_VERSION":                 "2.12.3",
			"MOCK_TEST_MODE":               "False",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "configmap-ricplt-xapp-onboarder-env",
		},
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
	}

	return []*corev1.ConfigMap{configMap1, configMap2, configMap3, configMap4, configMap5, configMap6, configMap7, configMap8, configMap9, configMap10, configMap11, configMap12, configMap13, configMap14, configMap15, configMap16, configMap17, configMap18, configMap19, configMap20, configMap21, configMap22, configMap23, configMap24, configMap25, configMap26, configMap27, configMap28, configMap29, configMap30, configMap31, configMap32, configMap33, configMap34, configMap35, configMap36, configMap37, configMap38}
}
