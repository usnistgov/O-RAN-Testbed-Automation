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
set -x

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -d ric-dep ]; then
    echo "ric-dep directory not found. Please ensure the repository has been cloned."
    exit 1
fi

if [ ! -d e2-interface ]; then
    echo "e2-interface directory not found. Please ensure the repository has been cloned."
    exit 1
fi

if [ ! -d xApps/kpimon-go ]; then
    echo "kpimon-go directory not found. Please ensure the repository has been cloned."
    exit 1
fi

if [ ! -d xApps/ad ]; then
    echo "ad directory not found. Please ensure the repository has been cloned."
    exit 1
fi

if [ ! -d xApps/ad-cell ]; then
    echo "ad-cell directory not found. Please ensure the repository has been cloned."
    exit 1
fi

if [ ! -d xApps/qp ]; then
    echo "qp directory not found. Please ensure the repository has been cloned."
    exit 1
fi

# Update ric-dep patch files
cp ric-dep/bin/install_k8s_and_helm.sh "$PARENT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.sh"

cd ric-dep

git diff depRicKubernetesOperator/internal/controller/getConfigmap.go >"$PARENT_DIR/install_patch_files/ric-dep/depRicKubernetesOperator/internal/controller/getConfigmap.go.patch"
git diff helm/e2mgr/templates/configmap.yaml >"$PARENT_DIR/install_patch_files/ric-dep/helm/e2mgr/templates/configmap.yaml.patch"
git diff helm/rtmgr/templates/config.yaml >"$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/config.yaml.patch"
git diff helm/rtmgr/templates/deployment.yaml >"$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/deployment.yaml.patch"
git diff new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml >"$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml.patch"
git diff new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml >"$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml.patch"
git diff new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.yaml >"$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.yaml.patch"

git restore bin/install_k8s_and_helm.sh
cp bin/install_k8s_and_helm.sh "$PARENT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.previous.sh"
cp bin/install_k8s_and_helm.sh bin/install_k8s_and_helm.previous.sh
cp "$PARENT_DIR/install_patch_files/ric-dep/bin/install_k8s_and_helm.sh" bin/install_k8s_and_helm.sh

git restore depRicKubernetesOperator/internal/controller/getConfigmap.go
cp depRicKubernetesOperator/internal/controller/getConfigmap.go "$PARENT_DIR/install_patch_files/ric-dep/depRicKubernetesOperator/internal/controller/getConfigmap.previous.go"
cp depRicKubernetesOperator/internal/controller/getConfigmap.go depRicKubernetesOperator/internal/controller/getConfigmap.previous.go
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/depRicKubernetesOperator/internal/controller/getConfigmap.go.patch"

git restore helm/e2mgr/templates/configmap.yaml
cp helm/e2mgr/templates/configmap.yaml "$PARENT_DIR/install_patch_files/ric-dep/helm/e2mgr/templates/configmap.previous.yaml"
cp helm/e2mgr/templates/configmap.yaml helm/e2mgr/templates/configmap.previous.yaml
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/helm/e2mgr/templates/configmap.yaml.patch"

git restore helm/rtmgr/templates/config.yaml
cp helm/rtmgr/templates/config.yaml "$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/config.previous.yaml"
cp helm/rtmgr/templates/config.yaml helm/rtmgr/templates/config.previous.yaml
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/config.yaml.patch"

git restore helm/rtmgr/templates/deployment.yaml
cp helm/rtmgr/templates/deployment.yaml "$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/deployment.previous.yaml"
cp helm/rtmgr/templates/deployment.yaml helm/rtmgr/templates/deployment.previous.yaml
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/helm/rtmgr/templates/deployment.yaml.patch"

git restore new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml
cp new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.previous.yaml"
cp new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.previous.yaml
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/e2mgr/templates/configmap.yaml.patch"

git restore new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml
cp new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/config.previous.yaml"
cp new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml new-installer/helm/charts/nearrtric/rtmgr/templates/config.previous.yaml
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/config.yaml.patch"

git restore new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.yaml
cp new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.yaml "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.previous.yaml"
cp new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.yaml new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.previous.yaml
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/ric-dep/new-installer/helm/charts/nearrtric/rtmgr/templates/deployment.yaml.patch"

cd "$PARENT_DIR"

# Update e2-interface
cp e2-interface/e2sim/src/messagerouting/e2ap_message_handler.cpp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/src/messagerouting/e2ap_message_handler.cpp"
cp e2-interface/e2sim/e2sm_examples/kpm_e2sm/reports.json "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/reports.json"
cp e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp"
cp e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp"

cd e2-interface

git restore e2sim/src/messagerouting/e2ap_message_handler.cpp
cp e2sim/src/messagerouting/e2ap_message_handler.cpp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/src/messagerouting/e2ap_message_handler.previous.cpp"
cp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/src/messagerouting/e2ap_message_handler.cpp" e2sim/src/messagerouting/e2ap_message_handler.cpp

git restore e2sim/e2sm_examples/kpm_e2sm/reports.json
cp e2sim/e2sm_examples/kpm_e2sm/reports.json "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/reports.previous.json"
cp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/reports.json" e2sim/e2sm_examples/kpm_e2sm/reports.json

git restore e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp
cp e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.previous.cpp"
cp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp" e2sim/e2sm_examples/kpm_e2sm/src/kpm/encode_kpm.cpp

git restore e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp
cp e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.previous.cpp"
cp "$PARENT_DIR/install_patch_files/e2-interface/e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp" e2sim/e2sm_examples/kpm_e2sm/src/kpm/kpm_callbacks.cpp

cd "$PARENT_DIR"

# Update KPI Monitor xApp patch files
cd xApps/kpimon-go

git diff e2sm/asn1/kpm2_0.asn >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/asn1/kpm2_0.asn.patch"
git diff --no-index -- /dev/null e2sm/headers/LogicalOR.h >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/headers/LogicalOR.h.patch" || [ "$?" -eq 1 ]
git diff --no-index -- /dev/null e2sm/headers/MatchingCondItem-Choice.h >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/headers/MatchingCondItem-Choice.h.patch" || [ "$?" -eq 1 ]
git diff e2sm/headers/MatchingCondItem.h >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/headers/MatchingCondItem.h.patch"
git diff --no-index -- /dev/null e2sm/lib/LogicalOR.c >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/lib/LogicalOR.c.patch" || [ "$?" -eq 1 ]
git diff --no-index -- /dev/null e2sm/lib/MatchingCondItem-Choice.c >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/lib/MatchingCondItem-Choice.c.patch" || [ "$?" -eq 1 ]
git diff e2sm/lib/MatchingCondItem.c >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/lib/MatchingCondItem.c.patch"
git diff e2sm/wrapper.c >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/wrapper.c.patch"
git diff control/control.go >"$PARENT_DIR/install_patch_files/xApps/kpimon-go/control/control.go.patch"

git restore e2sm/asn1/kpm2_0.asn
cp e2sm/asn1/kpm2_0.asn "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/asn1/kpm2_0.previous.asn"
cp e2sm/asn1/kpm2_0.asn e2sm/asn1/kpm2_0.previous.asn
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/asn1/kpm2_0.asn.patch"

git restore e2sm/headers/MatchingCondItem.h
cp e2sm/headers/MatchingCondItem.h "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/headers/MatchingCondItem.previous.h"
cp e2sm/headers/MatchingCondItem.h e2sm/headers/MatchingCondItem.previous.h
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/headers/MatchingCondItem.h.patch"

git restore e2sm/lib/MatchingCondItem.c
cp e2sm/lib/MatchingCondItem.c "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/lib/MatchingCondItem.previous.c"
cp e2sm/lib/MatchingCondItem.c e2sm/lib/MatchingCondItem.previous.c
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/lib/MatchingCondItem.c.patch"

git restore e2sm/wrapper.c
cp e2sm/wrapper.c "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/wrapper.previous.c"
cp e2sm/wrapper.c e2sm/wrapper.previous.c
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/kpimon-go/e2sm/wrapper.c.patch"

git restore control/control.go
cp control/control.go "$PARENT_DIR/install_patch_files/xApps/kpimon-go/control/control.go.previous"
cp control/control.go control/control.go.previous
git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/kpimon-go/control/control.go.patch"

cd "$PARENT_DIR"

# Update Anomaly Detection xApp patch files
cd xApps/ad

if ! git diff --quiet setup.py; then
    git diff setup.py >"$PARENT_DIR/install_patch_files/xApps/ad/setup.py.patch"
    git restore setup.py
    cp setup.py "$PARENT_DIR/install_patch_files/xApps/ad/setup.previous.py"
    cp setup.py setup.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/ad/setup.py.patch"
fi

if ! git diff --quiet src/ad_config.ini; then
    git diff src/ad_config.ini >"$PARENT_DIR/install_patch_files/xApps/ad/src/ad_config.ini.patch"
    git restore src/ad_config.ini
    cp src/ad_config.ini "$PARENT_DIR/install_patch_files/xApps/ad/src/ad_config.previous.ini"
    cp src/ad_config.ini src/ad_config.previous.ini
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/ad/src/ad_config.ini.patch"
fi

if ! git diff --quiet src/database.py; then
    git diff src/database.py >"$PARENT_DIR/install_patch_files/xApps/ad/src/database.py.patch"
    git restore src/database.py
    cp src/database.py "$PARENT_DIR/install_patch_files/xApps/ad/src/database.previous.py"
    cp src/database.py src/database.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/ad/src/database.py.patch"
fi

if ! git diff --quiet src/insert.py; then
    git diff src/insert.py >"$PARENT_DIR/install_patch_files/xApps/ad/src/insert.py.patch"
    git restore src/insert.py
    cp src/insert.py "$PARENT_DIR/install_patch_files/xApps/ad/src/insert.previous.py"
    cp src/insert.py src/insert.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/ad/src/insert.py.patch"
fi

cd "$PARENT_DIR"

# Update 5G Cell Anomaly Detection xApp patch files
cd xApps/ad-cell

if ! git diff --quiet src/configuration/config.ini; then
    git diff src/configuration/config.ini >"$PARENT_DIR/install_patch_files/xApps/ad-cell/src/configuration/config.ini.patch"
    git restore src/configuration/config.ini
    cp src/configuration/config.ini "$PARENT_DIR/install_patch_files/xApps/ad-cell/src/configuration/config.previous.ini"
    cp src/configuration/config.ini src/configuration/config.previous.ini
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/ad-cell/src/configuration/config.ini.patch"
fi

if ! git diff --quiet src/manager/InfluxDBManager.py; then
    git diff src/manager/InfluxDBManager.py >"$PARENT_DIR/install_patch_files/xApps/ad-cell/src/manager/InfluxDBManager.py.patch"
    git restore src/manager/InfluxDBManager.py
    cp src/manager/InfluxDBManager.py "$PARENT_DIR/install_patch_files/xApps/ad-cell/src/manager/InfluxDBManager.previous.py"
    cp src/manager/InfluxDBManager.py src/manager/InfluxDBManager.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/ad-cell/src/manager/InfluxDBManager.py.patch"
fi

cd "$PARENT_DIR"

# Update QoE Predictor xApp patch files
cd xApps/qp

if ! git diff --quiet insert.py; then
    git diff insert.py >"$PARENT_DIR/install_patch_files/xApps/qp/insert.py.patch"
    git restore insert.py
    cp insert.py "$PARENT_DIR/install_patch_files/xApps/qp/insert.previous.py"
    cp insert.py insert.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/qp/insert.py.patch"
fi

if ! git diff --quiet setup.py; then
    git diff setup.py >"$PARENT_DIR/install_patch_files/xApps/qp/setup.py.patch"
    git restore setup.py
    cp setup.py "$PARENT_DIR/install_patch_files/xApps/qp/setup.previous.py"
    cp setup.py setup.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/qp/setup.py.patch"
fi

if ! git diff --quiet src/database.py; then
    git diff src/database.py >"$PARENT_DIR/install_patch_files/xApps/qp/src/database.py.patch"
    git restore src/database.py
    cp src/database.py "$PARENT_DIR/install_patch_files/xApps/qp/src/database.previous.py"
    cp src/database.py src/database.previous.py
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/qp/src/database.py.patch"
fi

if ! git diff --quiet src/qp_config.ini; then
    git diff src/qp_config.ini >"$PARENT_DIR/install_patch_files/xApps/qp/src/qp_config.ini.patch"
    git restore src/qp_config.ini
    cp src/qp_config.ini "$PARENT_DIR/install_patch_files/xApps/qp/src/qp_config.previous.ini"
    cp src/qp_config.ini src/qp_config.previous.ini
    git apply --verbose --ignore-whitespace "$PARENT_DIR/install_patch_files/xApps/qp/src/qp_config.ini.patch"
fi

cd "$PARENT_DIR"

echo "Successfully updated the Near-RT RIC patch files."
