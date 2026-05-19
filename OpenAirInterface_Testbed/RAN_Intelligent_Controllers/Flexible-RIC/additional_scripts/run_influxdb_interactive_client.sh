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

INFLUXDB_ORG="xapp-kpm-moni"
INFLUXDB_BUCKET="xapp-kpm-moni"
INFLUXDB_TOKEN_PATH="$PARENT_DIR/influxdb_auth_token.json"

if [ ! -f "$INFLUXDB_TOKEN_PATH" ]; then
    echo "Creating an InfluxDB token to influxdb_auth_token.json..."
    influx auth create --all-access --json >"$INFLUXDB_TOKEN_PATH"
fi
INFLUXDB_TOKEN=$(jq -r '.token' "$INFLUXDB_TOKEN_PATH")

while true; do
    echo -e "\n----------------------------------------------------------------"
    echo -e "  InfluxDB Client"
    echo -e "  Org: $INFLUXDB_ORG | Bucket: $INFLUXDB_BUCKET"
    echo -e "----------------------------------------------------------------"
    echo -e "  1) List all buckets"
    echo -e "  2) List measurements in '$INFLUXDB_BUCKET' (last 1h)"
    echo -e "  3) List field keys in '$INFLUXDB_BUCKET' (last 1h)"
    echo -e "  4) Query data from '$INFLUXDB_BUCKET' (last 1h, limit 10)"
    echo -e "  5) Enter custom influx command (auto-appending --org and --token)"
    echo -e "  6) Exit"
    echo -e "----------------------------------------------------------------"
    read -e -p "Select a number: " OPTION

    case "$OPTION" in
    1)
        echo -e "\nRunning: influx bucket list..."
        influx bucket list --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    2)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> keep(columns: [\"_measurement\"]) |> distinct(column: \"_measurement\")"
        echo -e "\nRunning query for measurements in last 1 hour..."
        influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    3)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> keep(columns: [\"_field\"]) |> distinct(column: \"_field\")"
        echo -e "\nRunning query for field keys in last 1 hour..."
        influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    4)
        QUERY="from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> limit(n:10)"
        echo -e "\nRunning query for recent data (first 10 records)..."
        influx query "$QUERY" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        ;;
    5)
        echo -e "\n----- Command Examples ------"
        echo -e "  bucket list"
        echo -e "  query 'from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -24h)'"
        echo -e "  delete --bucket \"$INFLUXDB_BUCKET\" --start '1970-01-01T00:00:00Z' --stop \"\$(date --utc +%Y-%m-%dT%H:%M:%SZ)\" --predicate '_measurement=\"test\"'"
        echo -e "  write --bucket \"$INFLUXDB_BUCKET\" \"test_measurement,host=server01 value=0.64\""
        echo -e "-------------------------------"

        echo -e "Enter arguments for 'influx'. (Org ($INFLUXDB_ORG) and Token are automatically appended)"
        read -e -r -p "influx " -a CUSTOM_ARGS
        if [ ${#CUSTOM_ARGS[@]} -gt 0 ]; then
            influx "${CUSTOM_ARGS[@]}" --org "$INFLUXDB_ORG" --token "$INFLUXDB_TOKEN"
        fi
        ;;
    6)
        echo "Exiting..."
        break
        ;;
    *)
        echo "Invalid option. Please try again."
        ;;
    esac

    echo -e "\nPress Enter to return to menu..."
    read -r
done
