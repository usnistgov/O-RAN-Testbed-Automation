#!/bin/bash

kubectl get services -n ricplt | grep service-ricplt-appmgr

# Fetch the service information using kubectl and grep, and extract the appmgr IP and port
LINE=$(sudo kubectl get services -n ricplt | grep service-ricplt-appmgr-http)
IP_appmgr=$(echo $LINE | awk '{print $3}')
PORT_appmgr=$(echo $LINE | awk '{print $5}' | sed 's/\/.*//')

# Print the result
echo "https://$IP_appmgr:$PORT_appmgr"

curl http://$IP_appmgr:$PORT_appmgr/ric/v1/xapps | jq .

sudo kubectl get pod -n ricxapp
