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

set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Check dependencies
for CMD in jq curl kubectl uuidgen zip unzip; do
    if ! command -v "$CMD" &>/dev/null; then
        echo "ERROR: Missing dependency: $CMD" >&2
        exit 1
    fi
done

# Get rApp Manager IP
RAPP_MANAGER_IP=$(kubectl get pods -n nonrtric -l app.kubernetes.io/name=rappmanager -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
if [ -z "$RAPP_MANAGER_IP" ]; then
    RAPP_MANAGER_IP=$(kubectl get pods -n nonrtric -l app.kubernetes.io/name=rappmanager -o jsonpath='{.items[0].status.podIp}' 2>/dev/null)
fi

if [ -z "$RAPP_MANAGER_IP" ]; then
    echo "ERROR: rApp Manager IP not found." >&2
    exit 1
fi

echo "rApp manager address: $RAPP_MANAGER_IP"

RAPP_FILE="$1"
PAYLOAD_FILE="$2"

# Interactive selection
if [ -z "$RAPP_FILE" ]; then
    echo "Available rApps:"
    CSAR_FILES=(rApps/*.csar)

    if [ ${#CSAR_FILES[@]} -eq 0 ] || [ ! -e "${CSAR_FILES[0]}" ]; then
        echo "ERROR: No .csar files in rApps/." >&2
        exit 1
    fi

    for INDEX in "${!CSAR_FILES[@]}"; do
        echo "$((INDEX + 1)). $(basename "${CSAR_FILES[$INDEX]}")"
    done

    while true; do
        read -p "Select rApp (number): " SELECTION
        if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "${#CSAR_FILES[@]}" ]; then
            RAPP_FILE="${CSAR_FILES[$((SELECTION - 1))]}"
            break
        else
            echo "Invalid selection."
        fi
    done
fi

if [ ! -f "$RAPP_FILE" ]; then
    echo "ERROR: File not found: $RAPP_FILE" >&2
    exit 1
fi

# Get Host IP
HOST_IP=$(hostname -I | awk '{print $1}')

# CSAR Patching (Enabled)
patch_csar() {
    local csar_file="$1"
    local temp_dir=$(mktemp -d)
    echo "Checking CSAR compatibility..." >&2
    unzip -q "$csar_file" -d "$temp_dir"

    # Use HOST_IP variable instead of hardcoded IP
    if grep -r "http://$HOST_IP:8879/api/charts" "$temp_dir" >/dev/null; then
        echo "WARNING: Patching chartmuseum URL..." >&2
        grep -rl "http://$HOST_IP:8879/api/charts" "$temp_dir" | while read -r file; do
            if [[ "$file" == *.tgz ]] || [[ "$file" == *.gz ]] || [[ "$file" == *.zip ]]; then
                continue
            fi
            sed -i "s|http://$HOST_IP:8879/api/charts|http://$HOST_IP:8879/charts/api/charts|g" "$file"
        done
        cd "$temp_dir"
        zip -q -r patched_rapp.csar .
        cd - >/dev/null
        PATCHED_FILE="${csar_file%.csar}-patched.csar"
        mv "$temp_dir/patched_rapp.csar" "$PATCHED_FILE"
        rm -rf "$temp_dir"
        echo "$PATCHED_FILE"
    else
        echo "No patching needed." >&2
        rm -rf "$temp_dir"
        echo "$csar_file"
    fi
}
RAPP_FILE=$(patch_csar "$RAPP_FILE")

RAPP_ID=$(basename "$RAPP_FILE" .csar)
RAPP_ID=${RAPP_ID%-patched}

INSTANCE_ID=$(uuidgen)
BASE_URL="http://$RAPP_MANAGER_IP:8080"

echo "Processing $RAPP_ID ($INSTANCE_ID)"

# Check existing rApp
EXISTING_ID=$(curl -s "$BASE_URL/rapps" | jq -r --arg PKG "$(basename "$RAPP_FILE")" '.[] | select(.packageName == $PKG) | .name')

if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "$RAPP_ID" ]; then
    echo "Found existing rApp: $EXISTING_ID"
    RAPP_ID=$EXISTING_ID
fi

# Clean up existing instance if present
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/rapps/$RAPP_ID")
if [ "$HTTP_CODE" == "200" ]; then
    echo "Cleaning up existing rApp..."

    INSTANCES=$(curl -s "$BASE_URL/rapps/$RAPP_ID/instance" | jq -r 'keys[] // empty')
    for INSTANCE in $INSTANCES; do
        echo "Undeploying $INSTANCE..."
        curl -s -X PUT "$BASE_URL/rapps/$RAPP_ID/instance/$INSTANCE" -H 'Content-Type: application/json' -d '{"deployOrder": "UNDEPLOY"}' >/dev/null

        START_TIME=$(date +%s)
        TIMEOUT=30
        while true; do
            if [ $(($(date +%s) - START_TIME)) -gt $TIMEOUT ]; then
                echo "Timeout undeploying $INSTANCE"
                break
            fi
            STATE=$(curl -s "$BASE_URL/rapps/$RAPP_ID/instance/$INSTANCE" | jq -r ".state // .rappState")
            if [ "$STATE" == "UNDEPLOYED" ] || [ "$STATE" == "null" ]; then
                break
            fi
            sleep 2
        done

        echo "Deleting $INSTANCE..."
        curl -s -X DELETE "$BASE_URL/rapps/$RAPP_ID/instance/$INSTANCE"
    done

    echo "Depriming and deleting..."
    curl -s -X PUT "$BASE_URL/rapps/$RAPP_ID" -H 'Content-Type: application/json' -d '{"primeOrder": "DEPRIME"}' >/dev/null

    START_TIME=$(date +%s)
    TIMEOUT=60
    while true; do
        if [ $(($(date +%s) - START_TIME)) -gt $TIMEOUT ]; then
            echo "Timeout waiting for commissioned state." >&2
            break
        fi
        STATUS=$(curl -s "$BASE_URL/rapps/$RAPP_ID" | jq -r ".state // .rappState" 2>/dev/null)
        if [ "$STATUS" == "COMMISSIONED" ] || [ "$STATUS" == "null" ]; then
            break
        fi
        sleep 2
    done

    curl -s -X DELETE "$BASE_URL/rapps/$RAPP_ID" >/dev/null
    sleep 2
fi

echo "Commissioning $RAPP_ID..."
RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/rapps/$RAPP_ID" -F "file=@$RAPP_FILE")
HTTP_CODE=${RESPONSE: -3}
if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ] && [ "$HTTP_CODE" -ne 202 ]; then
    echo "ERROR: Commissioning failed ($HTTP_CODE)" >&2
    exit 1
fi

echo "Priming $RAPP_ID..."
curl -s -X PUT "$BASE_URL/rapps/$RAPP_ID" -H 'Content-Type: application/json' -d '{"primeOrder": "PRIME"}' >/dev/null

START_TIME=$(date +%s)
TIMEOUT=30
while true; do
    if [ $(($(date +%s) - START_TIME)) -gt $TIMEOUT ]; then
        echo "ERROR: Prime timeout." >&2
        exit 1
    fi
    STATUS=$(curl -s "$BASE_URL/rapps/$RAPP_ID" | jq -r ".state // .rappState" 2>/dev/null)
    if [ "$STATUS" == "PRIMED" ]; then
        break
    fi
    sleep 2
done

echo "Creating Instance for $RAPP_ID..."
TEMP_PAYLOAD=$(mktemp)
trap 'rm -f "$TEMP_PAYLOAD"' EXIT

if [ -n "$PAYLOAD_FILE" ]; then
    if [ ! -f "$PAYLOAD_FILE" ]; then
        echo "ERROR: Payload file missing: $PAYLOAD_FILE" >&2
        exit 1
    fi
    cp "$PAYLOAD_FILE" "$TEMP_PAYLOAD"
else
    if [[ "$RAPP_ID" == "rapp-simple-ics-consumer" ]]; then
        echo "{\"rappInstanceId\": \"$INSTANCE_ID\", \"acm\": {\"instance\": \"k8s-instance\"}, \"a1-policy\": {\"policyTypeId\": \"1\", \"policyInstanceId\": \"100\"}, \"dme\": {\"infoTypesProducer\": null, \"infoTypeConsumer\": \"type1\", \"infoProducer\": null, \"infoConsumer\": \"ics-simple-consumer\"}}" >"$TEMP_PAYLOAD"
    elif [[ "$RAPP_ID" == "rapp-hello-world" ]]; then
        echo "{\"rappInstanceId\": \"$INSTANCE_ID\", \"acm\": {\"instance\": \"k8s-instance\"}, \"sme\": {\"providerFunction\": \"provider-function-1\", \"serviceApis\": \"api-set-1\"}}" >"$TEMP_PAYLOAD"
    else
        echo "{}" >"$TEMP_PAYLOAD"
    fi
fi

RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/rapps/$RAPP_ID/instance" -H 'Content-Type: application/json' -d @"$TEMP_PAYLOAD")

HTTP_CODE=${RESPONSE: -3}
if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
    echo "ERROR: Create instance failed ($HTTP_CODE)" >&2
    exit 1
fi

START_TIME=$(date +%s)
TIMEOUT=30
while true; do
    if [ $(($(date +%s) - START_TIME)) -gt $TIMEOUT ]; then
        echo "ERROR: Wait undeployed timeout." >&2
        exit 1
    fi
    STATUS=$(curl -s "$BASE_URL/rapps/$RAPP_ID/instance/$INSTANCE_ID" | jq -r ".state" 2>/dev/null)
    if [ "$STATUS" == "UNDEPLOYED" ]; then
        break
    fi
    sleep 2
done

echo "Deploying $RAPP_ID ($INSTANCE_ID)..."
RESPONSE=$(curl -s -w "%{http_code}" -X PUT "$BASE_URL/rapps/$RAPP_ID/instance/$INSTANCE_ID" -H 'Content-Type: application/json' -d '{"deployOrder": "DEPLOY"}')

HTTP_CODE=${RESPONSE: -3}
if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 202 ]; then
    echo "ERROR: Deploy request failed ($HTTP_CODE)" >&2
    exit 1
fi

START_TIME=$(date +%s)
TIMEOUT=120
while true; do
    if [ $(($(date +%s) - START_TIME)) -gt $TIMEOUT ]; then
        echo "ERROR: Deployment timeout." >&2
        exit 1
    fi
    STATUS=$(curl -s "$BASE_URL/rapps/$RAPP_ID/instance/$INSTANCE_ID" | jq -r ".state" 2>/dev/null)
    if [ "$STATUS" == "DEPLOYED" ]; then
        break
    fi
    if [ "$STATUS" == "FAILED" ]; then
        echo "ERROR: Deployment FAILED." >&2
        exit 1
    fi
    sleep 2
done

echo "Successfully deployed $RAPP_ID, instance: $INSTANCE_ID."
