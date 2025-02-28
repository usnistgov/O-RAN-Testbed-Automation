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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

if [ ! -f influxdb_auth_token.json ]; then
    echo "Creating an InfluxDB token to influxdb_auth_token.json..."
    kubectl exec -it r4-influxdb-influxdb2-0 --namespace ricplt -- influx auth create --org influxdata --all-access --json >influxdb_auth_token.json
fi
INFLUXDB_TOKEN=$(jq -r '.token' influxdb_auth_token.json)

# Export the InfluxDB token for use in the InfluxDB CLI
kubectl exec -n ricplt -it r4-influxdb-influxdb2-0 -- /bin/sh -c "export TOKEN='$INFLUXDB_TOKEN'"
# Delete existing data point
# kubectl exec -n ricplt -it r4-influxdb-influxdb2-0 -- /bin/sh -c "influx delete --bucket \"kpimon\" --org \"influxdata\" --start '1970-01-01T00:00:00Z' --stop \"$(date --utc +%Y-%m-%dT%H:%M:%SZ)\" --predicate '_measurement=\"test_measurement\"'"
# Write data point with:
# kubectl exec -n ricplt -it r4-influxdb-influxdb2-0 -- /bin/sh -c "influx write --bucket \"kpimon\" --org \"influxdata\" --precision s \"test_measurement,host=server01 value=0.64 $(date +%s)\""

echo -e "\nConnecting to InfluxDB CLI within the Kubernetes pod..."
echo -e "Below are some example commands to interact with the InfluxDB database:\n"
echo -e "  List all buckets:"
echo -e "    influx bucket list --org influxdata --token \$TOKEN"
echo -e "  List data points from a measurement in last 24 hours:"
echo -e "    influx query 'from(bucket: \"kpimon\") |> range(start: -24h)' --org influxdata --token \$TOKEN"
echo -e "  List measurements in a bucket:"
echo -e "    influx query 'from(bucket: \"kpimon\") |> range(start: -1h) |> keep(columns: [\"_measurement\"]) |> distinct(column: \"_measurement\")' --org influxdata --token \$TOKEN"
echo -e "  List tag keys for a bucket:"
echo -e "    influx query 'from(bucket: \"kpimon\") |> range(start: -1h) |> keys()' --org influxdata --token \$TOKEN"
echo -e "  List field keys for a bucket:"
echo -e "    influx query 'from(bucket: \"kpimon\") |> range(start: -1h) |> keep(columns: [\"_field\"]) |> distinct(column: \"_field\")' --org influxdata --token \$TOKEN"
echo -e "  List tag values for a specific tag key:"
echo -e "    influx query 'import \"influxdata/influxdb/schema\"; schema.tagValues(bucket: \"kpimon\", tag: \"your-tag\")' --org influxdata --token \$TOKEN"
echo -e "\nType 'exit' twice to leave the InfluxDB CLI and return to your shell."

kubectl exec -n ricplt -it r4-influxdb-influxdb2-0 -- /bin/sh
