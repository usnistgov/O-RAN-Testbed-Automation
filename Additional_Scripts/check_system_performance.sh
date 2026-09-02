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
cd "$SCRIPT_DIR"

TEST_DURATION_SECONDS=10
WARMUP_SECONDS=2
CPU_MAX_PRIME=20000
MIN_STORAGE_MB=$((57 * 1000))
MIN_MEMORY_MB=6000
MIN_PROCESSORS=2
RECOMMENDED_PROCESSORS=6

export LC_ALL=C

if ! command -v sysbench &>/dev/null; then
    echo "Package \"sysbench\" not found, installing..."
    sudo env $APTVARS apt-get install -y sysbench
fi

PROCESSORS=$(nproc)
MEMORY_MB=$(awk '/MemTotal/ {print int($2 * 1024 / 1000000)}' /proc/meminfo)
STORAGE_TOTAL_MB=$(df -P --block-size=1000000 "$SCRIPT_DIR" | awk 'NR == 2 {print $2}')
STORAGE_AVAILABLE_MB=$(df -P --block-size=1000000 "$SCRIPT_DIR" | awk 'NR == 2 {print $4}')
CPU_MODEL=$(lscpu | awk -F: '/^Model name:/ {sub(/^[[:space:]]*/, "", $2); print $2; exit}')
VIRTUALIZATION=$(systemd-detect-virt 2>/dev/null || true)
if [ -z "$VIRTUALIZATION" ]; then
    VIRTUALIZATION="none"
fi

RESOURCE_WARNING=0

echo "System resources"
echo "    CPU: $CPU_MODEL"
echo "    Virtualization: $VIRTUALIZATION"

if [ "$PROCESSORS" -ge "$RECOMMENDED_PROCESSORS" ]; then
    echo "    Processors/vCPUs: $PROCESSORS"
elif [ "$PROCESSORS" -ge "$MIN_PROCESSORS" ]; then
    echo "    Processors/vCPUs: $PROCESSORS ($RECOMMENDED_PROCESSORS recommended)"
else
    echo "    WARNING: $PROCESSORS processors detected (minimum: $MIN_PROCESSORS)"
    RESOURCE_WARNING=1
fi

if [ "$MEMORY_MB" -ge "$MIN_MEMORY_MB" ]; then
    echo "    Memory: $MEMORY_MB MB"
else
    echo "    WARNING: $MEMORY_MB MB memory detected (minimum: $MIN_MEMORY_MB MB)"
    RESOURCE_WARNING=1
fi

if [ "$STORAGE_TOTAL_MB" -ge "$MIN_STORAGE_MB" ]; then
    echo "    Storage: $STORAGE_TOTAL_MB MB total, $STORAGE_AVAILABLE_MB MB available"
else
    echo "    WARNING: $STORAGE_TOTAL_MB MB storage detected (minimum: $MIN_STORAGE_MB MB)"
    RESOURCE_WARNING=1
fi

echo
echo "CPU benchmark"
echo "    $(sysbench --version)"
echo "    Settings: prime limit $CPU_MAX_PRIME, ${TEST_DURATION_SECONDS}s test, ${WARMUP_SECONDS}s warmup"

sysbench cpu --cpu-max-prime="$CPU_MAX_PRIME" --threads=1 --time="$WARMUP_SECONDS" run >/dev/null
SINGLE_THREAD_OUTPUT=$(sysbench cpu --cpu-max-prime="$CPU_MAX_PRIME" --threads=1 --time="$TEST_DURATION_SECONDS" run)
SINGLE_THREAD_EVENTS=$(awk '/events per second:/ {print $4; exit}' <<<"$SINGLE_THREAD_OUTPUT")
SINGLE_THREAD_LATENCY=$(awk '$1 == "95th" && $2 == "percentile:" {print $3; exit}' <<<"$SINGLE_THREAD_OUTPUT")

sysbench cpu --cpu-max-prime="$CPU_MAX_PRIME" --threads="$PROCESSORS" --time="$WARMUP_SECONDS" run >/dev/null
MULTI_THREAD_OUTPUT=$(sysbench cpu --cpu-max-prime="$CPU_MAX_PRIME" --threads="$PROCESSORS" --time="$TEST_DURATION_SECONDS" run)
MULTI_THREAD_EVENTS=$(awk '/events per second:/ {print $4; exit}' <<<"$MULTI_THREAD_OUTPUT")
MULTI_THREAD_LATENCY=$(awk '$1 == "95th" && $2 == "percentile:" {print $3; exit}' <<<"$MULTI_THREAD_OUTPUT")

if [ -z "$SINGLE_THREAD_EVENTS" ] || [ -z "$SINGLE_THREAD_LATENCY" ] || [ -z "$MULTI_THREAD_EVENTS" ] || [ -z "$MULTI_THREAD_LATENCY" ]; then
    echo "ERROR: Unable to read sysbench results" >&2
    exit 1
fi

CPU_SCALING=$(awk -v single="$SINGLE_THREAD_EVENTS" -v multi="$MULTI_THREAD_EVENTS" 'BEGIN {printf "%.2f", multi / single}')

echo "    Single-thread events/s: $SINGLE_THREAD_EVENTS"
echo "    Single-thread 95th percentile latency: $SINGLE_THREAD_LATENCY ms"
echo "    $PROCESSORS-thread events/s: $MULTI_THREAD_EVENTS"
echo "    $PROCESSORS-thread 95th percentile latency: $MULTI_THREAD_LATENCY ms"
echo "    Multi-thread scaling: ${CPU_SCALING}x"
echo "    Benchmark results are informational and are not used as a pass/fail threshold."
echo

if [ "$RESOURCE_WARNING" -eq 0 ]; then
    echo "Completed with no warnings"
else
    echo "Completed with warnings"
fi

echo "Successfully completed system performance check."
