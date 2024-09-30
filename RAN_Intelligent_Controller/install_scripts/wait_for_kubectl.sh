#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Exit immediately if a command fails
set -e

if ! systemctl is-active --quiet kubelet; then
    echo "Kubernetes service was not running, starting..."
    sudo systemctl start kubelet
fi

# Important: sudo systemctl status kube-apiserver

TIMEOUT=600
ELAPSED_TIME=0
SLEEP_DURATION=5
while ! sudo kubectl get --raw="/api/v1/namespaces/kube-system/pods" > /dev/null 2>&1; do
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        echo "Timeout exceeded while waiting for the API server to respond."
        echo "Attempting to restart Kubernetes services..."
        # Restart Kubernetes services or any other commands to recover the situation
        sudo systemctl restart kubelet
        sleep $SLEEP_DURATION
        ELAPSED_TIME=$SLEEP_DURATION
        echo "Services restarted. Continuing to wait for API server readiness..."
    else
        echo "Waiting for API server to respond..."
        if ! systemctl is-active --quiet kubelet; then
            echo "Kubernetes service was not running, starting..."
            sudo systemctl start kubelet
        fi
        sudo kubectl get pods --namespace=kube-system || true
        sudo kubectl get nodes || true
        sleep $SLEEP_DURATION
        ELAPSED_TIME=$(($ELAPSED_TIME + $SLEEP_DURATION))
    fi
done
