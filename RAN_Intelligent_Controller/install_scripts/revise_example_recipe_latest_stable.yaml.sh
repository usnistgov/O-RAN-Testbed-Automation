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

# Get the local IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Get the file path from the command line argument
FILE=$1

# Check if the file path is provided
if [[ -z "$FILE" ]]; then
    echo "Error: No file path provided."
    echo "Usage: $0 <path_to_yaml_file>"
    exit 1
fi

# Check if the file exists and is readable
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' does not exist."
    exit 1
fi

if [[ ! -r "$FILE" ]]; then
    echo "Error: File '$FILE' is not readable."
    exit 1
fi

# Use sed to find and replace the IP addresses in the ricip and auxip fields
sed -i "/extsvcplt:/,/^ *$/s/ricip: \".*\"/ricip: \"$IP_ADDRESS\"/" $FILE
sed -i "/extsvcplt:/,/^ *$/s/auxip: \".*\"/auxip: \"$IP_ADDRESS\"/" $FILE
echo "IP addresses updated to: $IP_ADDRESS in the file $FILE"

# Update Prometheus URL in vespamgr to point to r4-infrastructure
PROMETHEUS_NEW_URL="http://r4-infrastructure-prometheus-server.ricinfra"
# Check if the prometheusurl is present
if grep -q "prometheusurl:" $FILE; then
    # Proceed with updating if the key exists
    sed -i "/vespamgr:/,/prometheusurl:/s|prometheusurl: .*|prometheusurl: \"$PROMETHEUS_NEW_URL\"|" $FILE
    echo "Prometheus URL updated to $PROMETHEUS_NEW_URL in the file $FILE"
else
    echo "No Prometheus URL found in the vespamgr section of $FILE"
fi

# Function to add or update liveness and readiness probes
function update_probes {
    awk -v ip="$IP_ADDRESS" '
    # Initialize variables
    BEGIN {
        in_e2term = 0
        in_alpha = 0
        in_liveness = 0
        in_readiness = 0
        seen_liveness = 0
        seen_readiness = 0
        alpha_indent = ""
    }
    # Detect the e2term section
    /^e2term:/ {
        in_e2term = 1
    }
    # Detect the alpha section under e2term
    in_e2term && /^[ \t]+alpha:/ {
        in_alpha = 1
        # Capture the indentation of alpha section
        match($0, /^([ \t]+)/, m)
        alpha_indent = m[1]
    }
    # Detect the end of the alpha section
    in_alpha && /^[^ \t]/ {
        in_alpha = 0
        # If probes have not been seen, insert them
        if (!seen_liveness) {
            print alpha_indent "  livenessProbe:"
            print alpha_indent "    exec:"
            print alpha_indent "      command:"
            print alpha_indent "        - /bin/sh"
            print alpha_indent "        - -c"
            print alpha_indent "        - ip=`hostname -i`; export RMR_SRC_ID=$ip; /opt/e2/rmr_probe -h $ip:38000"
            print alpha_indent "    timeoutSeconds: 10"
            print alpha_indent "    periodSeconds: 10"
            print alpha_indent "    successThreshold: 1"
            print alpha_indent "    failureThreshold: 3"
        }
        if (!seen_readiness) {
            print alpha_indent "  readinessProbe:"
            print alpha_indent "    exec:"
            print alpha_indent "      command:"
            print alpha_indent "        - /bin/sh"
            print alpha_indent "        - -c"
            print alpha_indent "        - ip=`hostname -i`; export RMR_SRC_ID=$ip; /opt/e2/rmr_probe -h $ip:38000"
            print alpha_indent "    timeoutSeconds: 10"
            print alpha_indent "    periodSeconds: 60"
            print alpha_indent "    successThreshold: 1"
            print alpha_indent "    failureThreshold: 3"
        }
        # Reset flags
        in_e2term = 0
        alpha_indent = ""
        seen_liveness = 0
        seen_readiness = 0
    }
    # Detect existing livenessProbe block
    in_alpha && /^[ \t]+livenessProbe:/ {
        in_liveness = 1
        seen_liveness = 1
    }
    # Detect existing readinessProbe block
    in_alpha && /^[ \t]+readinessProbe:/ {
        in_readiness = 1
        seen_readiness = 1
    }
    # Adjust livenessProbe settings
    in_liveness {
        if (/^[ \t]+timeoutSeconds:/) {
            sub(/[0-9]+$/, "5")
        } else if (/^[ \t]+periodSeconds:/) {
            sub(/[0-9]+$/, in_liveness_period ? in_liveness_period : "10")
        }
    }
    # Adjust readinessProbe settings
    in_readiness {
        if (/^[ \t]+timeoutSeconds:/) {
            sub(/[0-9]+$/, "5")
        } else if (/^[ \t]+periodSeconds:/) {
            sub(/[0-9]+$/, in_readiness_period ? in_readiness_period : "60")
        }
    }
    # Exit livenessProbe block
    in_liveness && /^[^ \t]/ {
        in_liveness = 0
    }
    # Exit readinessProbe block
    in_readiness && /^[^ \t]/ {
        in_readiness = 0
    }
    {print}
    END {
        # In case the file ends and we are still in alpha
        if (in_alpha && (!seen_liveness || !seen_readiness)) {
            if (!seen_liveness) {
                print alpha_indent "  livenessProbe:"
                print alpha_indent "    exec:"
                print alpha_indent "      command:"
                print alpha_indent "        - /bin/sh"
                print alpha_indent "        - -c"
                print alpha_indent "        - ip=`hostname -i`; export RMR_SRC_ID=$ip; /opt/e2/rmr_probe -h $ip:38000"
                print alpha_indent "    timeoutSeconds: 5"
                print alpha_indent "    periodSeconds: 10"
                print alpha_indent "    successThreshold: 1"
                print alpha_indent "    failureThreshold: 3"
            }
            if (!seen_readiness) {
                print alpha_indent "  readinessProbe:"
                print alpha_indent "    exec:"
                print alpha_indent "      command:"
                print alpha_indent "        - /bin/sh"
                print alpha_indent "        - -c"
                print alpha_indent "        - ip=`hostname -i`; export RMR_SRC_ID=$ip; /opt/e2/rmr_probe -h $ip:38000"
                print alpha_indent "    initialDelaySeconds: 120"
                print alpha_indent "    timeoutSeconds: 5"
                print alpha_indent "    periodSeconds: 60"
                print alpha_indent "    successThreshold: 1"
                print alpha_indent "    failureThreshold: 3"
            }
        }
    }
    ' "$FILE" > tmpfile && mv tmpfile "$FILE"
}

# Call function to update probes
update_probes

echo "Probes updated in the file $FILE"
