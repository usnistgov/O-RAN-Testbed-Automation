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

echo "# Script: $(realpath $0)..."

# Exit immediately if a command fails
set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
cd $PARENT_DIR

INFLUXDB_PATH="$PARENT_DIR/influxdb"

sudo rm -rf influxdb_auth_token.json
sudo rm -rf "$INFLUXDB_PATH"

if ! kubectl get ns ricplt >/dev/null 2>&1; then
    kubectl create ns ricplt
fi

# Create the directory for InfluxDB storage and set permissions
mkdir -p "$INFLUXDB_PATH"
sudo chown -R nobody:nogroup "$INFLUXDB_PATH"
sudo chmod 775 "$INFLUXDB_PATH"

# List all the kubectl nodes, and prepare the values string for nodeAffinity
NODE_NAMES=($(kubectl get nodes --no-headers | awk '{print $1}'))
NODE_VALUES=""
if [ ${#NODE_NAMES[@]} -gt 0 ]; then
    NODE_VALUES="              - \"${NODE_NAMES[0]}\""
    for NODE_NAME in "${NODE_NAMES[@]:1}"; do
        NODE_VALUES="$NODE_VALUES"$'\n'"              - \"$NODE_NAME\""
    done
fi

# Create and apply PersistentVolume for InfluxDB
cat <<EOF >"$HOME/.kube/influxdb-pv.yaml"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: influxdb-local-pv
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: "$INFLUXDB_PATH"
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
$NODE_VALUES
EOF
kubectl apply -f "$HOME/.kube/influxdb-pv.yaml"

# Create and apply PersistentVolumeClaim for InfluxDB
cat <<EOF >"$HOME/.kube/influxdb-pvc.yaml"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: r4-influxdb-influxdb2
  namespace: ricplt
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF
kubectl apply -f "$HOME/.kube/influxdb-pvc.yaml"

# Create an NFS storage class for InfluxDB (causing the bin/install script will echo "nfs storage exist")
cat <<EOF >"$HOME/.kube/influxdb-nfs.yaml"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
kubectl apply -f "$HOME/.kube/influxdb-nfs.yaml"

# Check if the YAML editor is installed, and install it if not
if ! command -v yq &>/dev/null; then
    sudo ./install_scripts/install_yq.sh
fi
# Check that the correct version of yq is installed
if ! yq --version 2>/dev/null | grep -q 'https://github\.com/mikefarah/yq'; then
    echo "ERROR: Detected an incompatible yq installation."
    echo "Please ensure the Python yq is uninstalled with \"pip uninstall -y yq\", then re-run this script."
    exit 1
fi

INFLUXDB_VALUES_PATH="$PARENT_DIR/ric-dep/helm/influxdb/values.yaml"
INFLUXDB_VALUES_PATH2="$PARENT_DIR/ric-dep/helm/3rdparty/influxdb/values.yaml"

if [ ! -f "$PARENT_DIR/ric-dep/helm/influxdb/values.previous.yaml" ]; then
    cp "$INFLUXDB_VALUES_PATH" "$PARENT_DIR/ric-dep/helm/influxdb/values.previous.yaml"
fi

yq e '.fullnameOverride = "r4-influxdb-influxdb2"' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.enabled = true' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.storageClassName = "local-storage"' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.accessMode = "ReadWriteOnce"' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.size = "2Gi"' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.useExisting = true' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.name = "r4-influxdb-influxdb2"' -i $INFLUXDB_VALUES_PATH

if [ ! -f "$PARENT_DIR/ric-dep/helm/3rdparty/influxdb/values.previous.yaml" ]; then
    cp "$INFLUXDB_VALUES_PATH2" "$PARENT_DIR/ric-dep/helm/influxdb/values.previous.yaml"
fi

yq e '.fullnameOverride = "r4-influxdb-influxdb2"' -i $INFLUXDB_VALUES_PATH
yq e '.persistence.enabled = true' -i $INFLUXDB_VALUES_PATH2
yq e '.persistence.storageClassName = "local-storage"' -i $INFLUXDB_VALUES_PATH2
yq e '.persistence.accessMode = "ReadWriteOnce"' -i $INFLUXDB_VALUES_PATH2
yq e '.persistence.size = "2Gi"' -i $INFLUXDB_VALUES_PATH2
yq e '.persistence.useExisting = true' -i $INFLUXDB_VALUES_PATH2
yq e '.persistence.name = "r4-influxdb-influxdb2"' -i $INFLUXDB_VALUES_PATH2
