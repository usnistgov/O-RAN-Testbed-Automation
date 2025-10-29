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

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$(dirname "$SCRIPT_DIR")"
RECIPE_PATHS=(
    "ric-dep/new-installer/helm/charts/nearrtric/e2term/templates/deployment.yaml"
    "ric-dep/helm/e2term/templates/deployment.yaml"
)

CONFIGMAP_PATHS=(
    "ric-dep/new-installer/helm/charts/nearrtric/e2term/templates/configmap-e2config.yaml"
    "ric-dep/helm/e2term/templates/configmap-e2config.yaml"
)
echo "Creating ConfigMap templates..."

for CONFIGMAP_FILE in "${CONFIGMAP_PATHS[@]}"; do
    echo "ConfigMap: $CONFIGMAP_FILE"

    cat >"$CONFIGMAP_FILE" <<'EOF'
{{- $topCtx :=  . }}
{{- range keys .Values.e2term }}
{{- $key := . }}
{{- with index $topCtx.Values.e2term . }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.configmapname.e2term" $topCtx }}-config-{{ $key }}
  namespace: {{ include "common.namespace.platform" $topCtx }}
data:
  config.conf: |
    nano={{ include "common.serviceport.e2term.rmr.data" $topCtx }}
    volume={{ .env.messagecollectorfile }}
    local-ip={{ include "common.servicename.e2term.rmr" $topCtx }}-{{ $key }}.{{ include "common.namespace.platform" $topCtx }}
    prometheusMode=pull
    prometheusPushTimeOut=10
    prometheusPushAddr=127.0.0.1:7676
    prometheusPort={{ include "common.serviceport.e2term.prometheus" $topCtx }}
    trace=stop
    external-fqdn={{ include "common.servicename.e2term.rmr" $topCtx }}-{{ $key }}.{{ include "common.namespace.platform" $topCtx }}
    pod_name=E2TERM_POD_NAME
    sctp-port={{ include "common.serviceport.e2term.sctp" $topCtx }}
{{- end }}
{{- end }}
EOF

    echo "Successfully created $CONFIGMAP_FILE"
done

echo
echo "Updating deployment volume mounts..."

for RECIPE_PATH in "${RECIPE_PATHS[@]}"; do
    if [ -f "$RECIPE_PATH" ]; then
        echo "Deployment: $RECIPE_PATH"

        # Add volume mount if not present
        if ! grep -q 'name: e2term-config-volume' "$RECIPE_PATH"; then
            # Insert volumeMounts section so that e2term can access the config
            awk '
                /volumeMounts:/ && !added {
                    print $0;
                    print "          - mountPath: /opt/e2/config";
                    print "            name: e2term-config-volume";
                    added=1;
                    next;
                }
                { print $0 }
            ' "$RECIPE_PATH" >"$RECIPE_PATH.tmp" && mv "$RECIPE_PATH.tmp" "$RECIPE_PATH"

            # Insert volumes section for the config map
            awk '
                /^      volumes:/ && !added {
                    print $0;
                    print "        - name: e2term-config-volume";
                    print "          configMap:";
                    print "            name: {{ include \"common.configmapname.e2term\" $topCtx }}-config-{{ $key }}";
                    added=1;
                    next;
                }
                { print $0 }
            ' "$RECIPE_PATH" >"$RECIPE_PATH.tmp" && mv "$RECIPE_PATH.tmp" "$RECIPE_PATH"

            echo "Successfully added volume mount."
        else
            echo "Volume mount already exists. Skipping."
        fi
    fi
done

echo "Successfully configured E2 Terminator SCTP port."
