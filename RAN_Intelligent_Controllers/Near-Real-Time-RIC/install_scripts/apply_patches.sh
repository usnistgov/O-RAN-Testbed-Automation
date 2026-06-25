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

# Exit immediately if a command fails
set -e

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

echo "Copying over install_k8s_and_helm.sh..."
if [ ! -f "ric-dep/bin/install_k8s_and_helm.previous.sh" ]; then
    cp ric-dep/bin/install_k8s_and_helm.sh ric-dep/bin/install_k8s_and_helm.previous.sh
    cp ric-dep/bin/install_k8s_and_helm.previous.sh "$PARENT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.previous.sh"
fi
cp "$PARENT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.sh" ric-dep/bin/install_k8s_and_helm.sh

# Prevent Helm from using backup templates as duplicate resources
rm -f "$PARENT_DIR/ric-dep/helm/e2mgr/templates/configmap.previous.yaml"
rm -f "$PARENT_DIR/ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.previous.yaml"

# The following patches ensure that the e2term RMR has "alpha"
echo "Patching getConfigmap.go and configmap.yaml so that E2 nodes don't disconnect..."
cd "ric-dep/depRicKubernetesOperator/internal/controller"
git restore getConfigmap.go
if [ ! -f "getConfigmap.previous.go" ]; then
    echo "Patching getConfigmap.go..."
    cp getConfigmap.go getConfigmap.previous.go
    cp getConfigmap.previous.go "$PARENT_DIR/install_patch_files/ric-dep/depRicKubernetesOperator/internal/controller/getConfigmap.previous.go"
fi
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/depRicKubernetesOperator/internal/controller/getConfigmap.go.patch"
cd "$PARENT_DIR"
cd "ric-dep/helm/e2mgr/templates"
git restore configmap.yaml
cp configmap.yaml "$PARENT_DIR/install_patch_files/ric-dep/helm/e2mgr/templates/configmap.previous.yaml"
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/helm/e2mgr/templates/configmap.yaml.patch"
cd "$PARENT_DIR"
cd "ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates"
git restore configmap.yaml
cp configmap.yaml "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.previous.yaml"
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml.patch"
cd "$PARENT_DIR"

echo "Patching rtmgr route templates to keep E2_TERM_KEEP_ALIVE_REQ route..."
cd "ric-dep/helm/rtmgr/templates"
git restore config.yaml
cp config.yaml "$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/config.previous.yaml"
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/config.yaml.patch"
cd "$PARENT_DIR"
cd "ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates"
git restore config.yaml
cp config.yaml "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/config.previous.yaml"
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml.patch"
cd "$PARENT_DIR"

echo "Successfully patched ric-dep."
