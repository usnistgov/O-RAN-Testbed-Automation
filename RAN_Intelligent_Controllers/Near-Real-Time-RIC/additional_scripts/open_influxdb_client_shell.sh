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

echo -e "\nConnecting to InfluxDB CLI within the Kubernetes pod..."
echo -e "Once inside the pod, type 'influx' to start the InfluxDB CLI."
echo -e "Below are some example commands to interact with the InfluxDB database:\n"
echo -e "  List all buckets:"
echo -e "    influx bucket list"
echo -e "  List last 10 data points from a measurement:"
echo -e "    influx query 'from(bucket: \"your-bucket\") |> range(start: -1h) |> limit(n:10)'"
echo -e "  List measurements in a bucket:"
echo -e "    influx query 'import \"influxdata/influxdb/schema\"; schema.measurements(bucket: \"your-bucket\")'"
echo -e "  List tag keys for a bucket:"
echo -e "    influx query 'import \"influxdata/influxdb/schema\"; schema.tagKeys(bucket: \"your-bucket\")'"
echo -e "  List field keys for a bucket:"
echo -e "    influx query 'import \"influxdata/influxdb/schema\"; schema.fieldKeys(bucket: \"your-bucket\")'"
echo -e "  List tag values for a specific tag key:"
echo -e "    influx query 'import \"influxdata/influxdb/schema\"; schema.tagValues(bucket: \"your-bucket\", tag: \"your-tag\")'"
echo -e "\nType 'exit' to leave the InfluxDB CLI and return to your shell."

kubectl exec -n ricplt -it r4-influxdb-influxdb2-0 -- /bin/sh
