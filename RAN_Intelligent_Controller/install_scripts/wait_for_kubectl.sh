#!/bin/bash
#
# NIST-developed software is provided by NIST as a public service. You may use,
# copy, and distribute copies of the software in any medium, provided that you
# keep intact this entire notice. You may improve, modify, and create derivative
# works of the software or any portion of the software, and you may copy and
# distribute such modifications or works. Modified works should carry a notice
# stating that you changed the software and should note the date and nature of
# any such change. Please explicitly acknowledge the National Institute of
# Standards and Technology as the source of the software.
#
# NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
# OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
# NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
# UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
# NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
# THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
# RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
#
# You are solely responsible for determining the appropriateness of using and
# distributing the software and you assume all risks associated with its use,
# including but not limited to the risks and costs of program errors, compliance
# with applicable laws, damage to or loss of data, programs or equipment, and
# the unavailability or interruption of operation. This software is not intended
# to be used in any situation where a failure could cause risk of injury or
# damage to property. The software developed by NIST employees is not subject to
# copyright protection within the United States.

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
while ! kubectl get --raw="/api/v1/namespaces/kube-system/pods" > /dev/null 2>&1; do
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
        kubectl get pods --namespace=kube-system || true
        kubectl get nodes || true
        sleep $SLEEP_DURATION
        ELAPSED_TIME=$(($ELAPSED_TIME + $SLEEP_DURATION))
    fi
done
