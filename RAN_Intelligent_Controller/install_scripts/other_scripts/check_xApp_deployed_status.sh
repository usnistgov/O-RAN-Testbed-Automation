#!/bin/bash

# Get the ClusterIP for the -http service of the app manager
IP=$(kubectl get services -n ricplt | grep service-ricplt-appmgr-http | awk '{print $3}')

# Output the IP being checked
echo "Checking status of xApps at ClusterIP $IP."

# Perform the curl request to fetch xApps status
curl -s http://$IP:8080/ric/v1/xapps | jq .

echo ""
echo "List of Kubernetes pod xApps:"
kubectl get po -n ricxapp