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

INFLUXDB_ORG="influxdata"
INFLUXDB_BUCKET="kpimon"
INFLUXDB_POD="r4-influxdb-influxdb2-0"
INFLUXDB_TOKEN_PATH="$PARENT_DIR/influxdb_auth_token.json"

if [ ! -s "$INFLUXDB_TOKEN_PATH" ]; then
    echo "Creating an InfluxDB token to influxdb_auth_token.json..."
    kubectl exec "$INFLUXDB_POD" --namespace ricplt -- influx auth create --org "$INFLUXDB_ORG" --all-access --json >"$INFLUXDB_TOKEN_PATH"
fi
INFLUXDB_TOKEN=$(jq -r '.token' "$INFLUXDB_TOKEN_PATH")
if [ -z "$INFLUXDB_TOKEN" ] || [ "$INFLUXDB_TOKEN" = "null" ]; then
    echo "Could not read an InfluxDB token from $INFLUXDB_TOKEN_PATH."
    exit 1
fi

# Delete existing data point
# kubectl exec -n ricplt -it "$INFLUXDB_POD" -- /bin/sh -c "influx delete --bucket \"kpimon\" --org \"influxdata\" --start '1970-01-01T00:00:00Z' --stop \"$(date --utc +%Y-%m-%dT%H:%M:%SZ)\" --predicate '_measurement=\"test_measurement\"'"
# Write data point with:
# kubectl exec -n ricplt -it "$INFLUXDB_POD" -- /bin/sh -c "influx write --bucket \"kpimon\" --org \"influxdata\" --precision s \"test_measurement,host=server01 value=0.64 $(date +%s)\""

while true; do
    echo
    echo "----------------------------------------------------------------"
    echo "  Near-RT RIC InfluxDB Client"
    echo "  Org: $INFLUXDB_ORG | Bucket: $INFLUXDB_BUCKET"
    echo "----------------------------------------------------------------"
    echo "  1) List all buckets"
    echo "  2) List measurements in '$INFLUXDB_BUCKET' (last 1h)"
    echo "  3) List field keys in '$INFLUXDB_BUCKET' (last 1h)"
    echo "  4) View current KPI metrics"
    echo "  5) View the latest 20 KPI records"
    echo "  6) Enter a custom influx command"
    echo "  7) Open an interactive shell in the InfluxDB pod"
    echo "  8) Exit"
    echo "----------------------------------------------------------------"
    read -e -r -p "Select a number: " OPTION

    case "$OPTION" in
    1)
        kubectl exec -n ricplt "$INFLUXDB_POD" -- influx bucket list --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    2)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> keep(columns: [\"_measurement\"]) |> distinct(column: \"_measurement\")"
        kubectl exec -n ricplt "$INFLUXDB_POD" -- influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    3)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> keep(columns: [\"_field\"]) |> distinct(column: \"_field\")"
        kubectl exec -n ricplt "$INFLUXDB_POD" -- influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    4)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -24h) |> filter(fn: (r) => r._measurement == \"UeMetrics\" or r._measurement == \"cellMetrics\") |> last() |> keep(columns: [\"_measurement\", \"_field\", \"_value\"])"
        echo
        echo "Latest KPI metrics:"
        kubectl exec -n ricplt "$INFLUXDB_POD" -- influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN" --raw | python3 -c 'import csv
import json
import math
import sys

header = None
metrics = []
for line in sys.stdin:
    if not line.strip() or line.startswith("#"):
        continue
    row = next(csv.reader([line]))
    if "_value" in row and "_field" in row:
        header = row
        continue
    if header is None:
        continue
    record = dict(zip(header, row))
    measurement = record.get("_measurement", "")
    field = record.get("_field", "")
    value = record.get("_value", "")
    if measurement and field and value != "":
        metrics.append((measurement, field, value))

if not metrics:
    print("  No UeMetrics or cellMetrics samples found during the last 24 hours.")
    raise SystemExit


def flatten_numbers(value):
    numbers = []
    if isinstance(value, list):
        for item in value:
            numbers.extend(flatten_numbers(item))
    elif (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    ):
        numbers.append(value)
    return numbers


def format_number(value):
    return "{:.6g}".format(value)


cyan = "\033[36m"
reset = "\033[0m"
current_measurement = ""
for measurement, field, value in sorted(metrics):
    if measurement != current_measurement:
        current_measurement = measurement
        print("\n" + measurement)

    try:
        parsed = json.loads(value)
    except (json.JSONDecodeError, TypeError):
        parsed = None

    if isinstance(parsed, list):
        numbers = flatten_numbers(parsed)
        if numbers:
            output = (
                (field + ".Min", format_number(min(numbers))),
                (field + ".Mean", format_number(math.fsum(numbers) / len(numbers))),
                (field + ".Max", format_number(max(numbers))),
                (field + ".Count", str(len(numbers))),
            )
        else:
            output = (
                (field + ".Min", "NULL"),
                (field + ".Mean", "NULL"),
                (field + ".Max", "NULL"),
                (field + ".Count", "0"),
            )
        for name, result in output:
            print("  " + cyan + name + reset + " = " + result)
    else:
        print("  " + cyan + field + reset + " = " + value)
'
        ;;
    5)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> filter(fn: (r) => r._measurement == \"UeMetrics\" or r._measurement == \"cellMetrics\") |> pivot(rowKey: [\"_time\", \"_measurement\"], columnKey: [\"_field\"], valueColumn: \"_value\") |> sort(columns: [\"_time\"], desc: true) |> limit(n: 20)"
        kubectl exec -n ricplt "$INFLUXDB_POD" -- influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    6)
        echo
        echo "Examples:"
        echo "  bucket list"
        echo "  auth list"
        echo "For commands requiring complex shell quoting, use option 7."
        read -e -r -p "influx " -a CUSTOM_ARGS
        if [ "${#CUSTOM_ARGS[@]}" -gt 0 ]; then
            kubectl exec -n ricplt "$INFLUXDB_POD" -- influx "${CUSTOM_ARGS[@]}" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        fi
        ;;
    7)
        echo "INFLUX_TOKEN, INFLUX_ORG, and INFLUX_BUCKET are available in the pod shell."
        kubectl exec -n ricplt -it "$INFLUXDB_POD" -- env INFLUX_TOKEN="$INFLUXDB_TOKEN" INFLUX_ORG="$INFLUXDB_ORG" INFLUX_BUCKET="$INFLUXDB_BUCKET" /bin/sh
        ;;
    8)
        echo "Exiting..."
        break
        ;;
    *)
        echo "Invalid option. Please try again."
        ;;
    esac

    if [ "$OPTION" != "8" ]; then
        echo
        read -r -p "Press Enter to return to the menu..."
    fi
done
