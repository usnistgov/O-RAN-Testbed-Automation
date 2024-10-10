#!/bin/bash

export CHART_REPO_URL=http://0.0.0.0:8090
sudo sed -i '/CHART_REPO_URL/d' /etc/environment
echo "CHART_REPO_URL=$CHART_REPO_URL" | sudo tee -a /etc/environment > /dev/null
source /etc/environment