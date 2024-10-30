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
set -x

SCRIPT_DIR=$(dirname "$(realpath "$0")")
XAPPS_DIR=$(dirname "$SCRIPT_DIR")/xApps
mkdir -p $XAPPS_DIR

cd $XAPPS_DIR
if [ ! -d "kpimon" ]; then
    echo "Cloning KPI Monitor xApp..."
    git clone https://gerrit.o-ran-sc.org/r/scp/ric-app/kpimon
fi
cd kpimon

echo "Creating and modifying the configuration file xapp-descriptor/config_MODIFIED.json"
# Check if jq is installed; if not, install it
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update
    sudo apt-get install -y jq
fi

if [ ! -f "xapp-descriptor/config_MODIFIED.json" ]; then
    FILE="xapp-descriptor/config_MODIFIED.json"
    cp xapp-descriptor/config.json $FILE
    # Modify the required fields using jq and overwrite the original file
    jq '.containers[0].image.tag = "1.0.0" |
        .containers[0].image.registry = "example.com:80" |
        .containers[0].image.name = "kpimon"' "$FILE" >tmp.$$.json && mv tmp.$$.json "$FILE"
fi

# Create a backup of the original Dockerfile if it doesn't already exist
if [ ! -f Dockerfile.backup ]; then
    cp Dockerfile Dockerfile.backup
fi
cp Dockerfile.backup Dockerfile

# Patch the first line to update the base image
OLD_LINE="FROM nexus3.o-ran-sc.org:10004/o-ran-sc/bldr-ubuntu18-c-go:1.9.0 as kpimonbuild"
NEW_LINE="FROM nexus3.o-ran-sc.org:10002/o-ran-sc/bldr-ubuntu20-c-go:1.0.0 as kpimonbuild"
sed -i "/^${OLD_LINE//\//\\/}$/ {
    s|^|# |
    a ${NEW_LINE}
}" "Dockerfile"

CLONE_GOLOG="RUN mkdir -p \$GOPATH/src/gerrit.o-ran-sc.org/r/com && git clone https://github.com/o-ran-sc/com-golog.git \$GOPATH/src/gerrit.o-ran-sc.org/r/com/golog"
# Insert the cloning command right after setting the work directory for the modules
INSERT_AFTER="WORKDIR /go/src/gerrit.o-ran-sc.org/r/ric-plt"
sed -i "/^${INSERT_AFTER//\//\\/}$/a ${CLONE_GOLOG//\//\\/}" "Dockerfile"

# Ensure module initialization, adding 'require' statements, and tidy are included after setting the work directory for kpimon
OLD_LINE="WORKDIR /go/src/gerrit.o-ran-sc.org/r/scp/ric-app/kpimon"
NEW_LINE1="RUN if [ ! -f go.mod ]; then \
    go mod init gerrit.o-ran-sc.org/r/scp/ric-app/kpimon && \
    echo 'replace gerrit.o-ran-sc.org/r/ric-plt/sdlgo => /go/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo' >> go.mod && \
    echo 'replace gerrit.o-ran-sc.org/r/ric-plt/xapp-frame => /go/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame' >> go.mod && \
    echo 'replace gerrit.o-ran-sc.org/r/com/golog => /go/src/gerrit.o-ran-sc.org/r/com/golog' >> go.mod && \
    echo 'require gerrit.o-ran-sc.org/r/ric-plt/sdlgo v0.0.0' >> go.mod && \
    echo 'require gerrit.o-ran-sc.org/r/ric-plt/xapp-frame v0.0.0' >> go.mod && \
    echo 'require gerrit.o-ran-sc.org/r/com/golog v0.0.0' >> go.mod && \
    go mod edit -replace=gerrit.o-ran-sc.org/r/ric-plt/sdlgo=/go/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo && \
    go mod edit -replace=gerrit.o-ran-sc.org/r/ric-plt/xapp-frame=/go/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame && \
    go mod edit -replace=gerrit.o-ran-sc.org/r/com/golog=/go/src/gerrit.o-ran-sc.org/r/com/golog; \
fi"
NEW_LINE2="RUN go mod tidy || echo \"Warning: mod tidy found unresolved dependencies\""
sed -i "/^${OLD_LINE//\//\\/}$/ {
    a ${NEW_LINE1//\//\\/}
    a ${NEW_LINE2//\//\\/}
}" "Dockerfile"

# Patch the git clone command for sdlgo to ensure proper path and module initialization
OLD_LINE="RUN git clone \"https://gerrit.o-ran-sc.org/r/ric-plt/sdlgo\""
NEW_LINE1="RUN mkdir -p \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo && git clone \"https://gerrit.o-ran-sc.org/r/ric-plt/sdlgo\" \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo || git clone https://github.com/o-ran-sc/ric-plt-sdlgo.git \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo"
NEW_LINE2="RUN if [ ! -f \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo/go.mod ]; then cd \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/sdlgo && go mod init gerrit.o-ran-sc.org/r/ric-plt/sdlgo; fi"
sed -i "/^${OLD_LINE//\//\\/}$/ {
    s|^|# |
    a ${NEW_LINE1//\//\\/}
    a ${NEW_LINE2//\//\\/}
}" "Dockerfile"

# Patch the git clone command for xapp-frame to ensure proper path and module initialization
OLD_LINE="RUN git clone -b \${XAPPFRAMEVERSION} \"https://gerrit.o-ran-sc.org/r/ric-plt/xapp-frame\""
NEW_LINE1="RUN mkdir -p \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame && git clone -b \${XAPPFRAMEVERSION} \"https://gerrit.o-ran-sc.org/r/ric-plt/xapp-frame\" \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame || git clone -b \${XAPPFRAMEVERSION} https://github.com/o-ran-sc/ric-plt-xapp-frame.git \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame"
NEW_LINE2="RUN if [ ! -f \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame/go.mod ]; then cd \$GOPATH/src/gerrit.o-ran-sc.org/r/ric-plt/xapp-frame && go mod init gerrit.o-ran-sc.org/r/ric-plt/xapp-frame; fi"
sed -i "/^${OLD_LINE//\//\\/}$/ {
    s|^|# |
    a ${NEW_LINE1//\//\\/}
    a ${NEW_LINE2//\//\\/}
}" "Dockerfile"

sudo docker build -t example.com:80/kpimon:1.0.0 .

if [ "$CHART_REPO_URL" != "http://0.0.0.0:8090" ]; then
    export CHART_REPO_URL=http://0.0.0.0:8090
fi

sudo docker save -o kpimon.tar example.com:80/kpimon:1.0.0

sudo ctr -n=k8s.io image import kpimon.tar

# Run the dms_cli onboard command and capture the output
OUTPUT=$(dms_cli onboard ./xapp-descriptor/config_MODIFIED.json ./xapp-descriptor/schema.json)
echo $OUTPUT
if echo "$OUTPUT" | grep -q '"status": "Created"'; then
    echo "Onboarding successful: status is 'Created'."
else
    echo "Onboarding failed or 'Created' status not found."
    exit 1
fi

echo "Checking if namespace 'ricxapp' exists..."
if ! kubectl get namespace ricxapp &>/dev/null; then
    echo "Namespace 'ricxapp' does not exist. Creating it..."
    kubectl create namespace ricxapp
fi

# Check if the xApp is already installed and uninstall it if necessary
if dms_cli get_charts_list | grep -q 'kpimon' || true; then
    echo "Uninstalling application 'kpimon'..."
    UNINSTALL_OUTPUT=$(dms_cli uninstall kpimon ricxapp 2>&1) || true
    if echo "$UNINSTALL_OUTPUT" | grep -q 'release: not found\|No Xapp to uninstall' || true; then
        echo "Application kpimon not found or already uninstalled."
    else
        echo "$UNINSTALL_OUTPUT"
    fi
fi

echo "Installing application 'kpimon'..."
OUTPUT=$(dms_cli install kpimon 1.0.0 ricxapp || echo "Failed to install kpimon xApp with dms_cli.")
echo "$OUTPUT"
if [[ "$OUTPUT" == *"status: OK"* ]]; then
    echo "Application successfully installed."
else
    echo "Application failed to install."
    exit 1
fi
