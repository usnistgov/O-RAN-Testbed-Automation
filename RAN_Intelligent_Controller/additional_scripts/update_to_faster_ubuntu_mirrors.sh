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

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

echo "Optimizing Ubuntu apt sources (/etc/apt/sources.list) to get faster download rates..."

# Number of times to measure apt sources, a higher value will give better results but take longer
NUM_ITERATIONS=3

# Fetch the Ubuntu codename
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_CODENAME=${VERSION_CODENAME:-$(lsb_release -sc)}
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    UBUNTU_CODENAME=${DISTRIB_CODENAME:-$(lsb_release -sc)}
else
    UBUNTU_CODENAME=$(lsb_release -sc 2>/dev/null)
    if [ -z "$UBUNTU_CODENAME" ]; then
        echo "Unable to find distro codename. Make sure you are running an Ubuntu derivative."
        exit 1
    fi
fi

# Update package lists
if ! apt-get update -y; then
    echo "Failed to update package lists. Please check your network or sources.list file."
    exit 1
fi

# Function to check and install a package
install_package() {
    local PACKAGE=$1
    local CMD=$2
    if ! command -v $CMD &> /dev/null; then
        echo "$PACKAGE is not installed. Installing..."
        apt-get install -y $PACKAGE
    fi
}

# Install curl
install_package curl curl

# Install Python3 pip if not already installed
install_package python3-pip pip3

# Install Python3 virtual environment utilities
install_package python3-venv python3-venv

# Save the current directory and create a temporary directory
CURRENT_DIR=$(pwd)
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# Create and activate a Python virtual environment
VENV_DIR="$WORKDIR/venv"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Install apt-select using pip in the virtual environment
echo "Installing apt-select..."
pip install apt-select

# Verify apt-select installation
if ! command -v apt-select &> /dev/null; then
    echo "Failed to install apt-select. Please check your Python/pip configuration."
    deactivate
    exit 1
fi

# Test mirrors multiple times for consistency
echo "Testing mirrors multiple times for consistency..."
declare -A MIRROR_COUNTS
MIRROR_COUNTS=()
for i in {1..$NUM_ITERATIONS}; do
    echo "Test $i..."
    echo "1" | apt-select -t 20 -m up-to-date -c

    NEW_MIRROR=$(grep '^deb' sources.list | awk '{print $2}' | head -n1)

    MIRROR_COUNTS["$NEW_MIRROR"]=$((MIRROR_COUNTS["$NEW_MIRROR"] + 1))
done

# Find the mirror with the highest count
BEST_MIRROR=""
MAX_COUNT=0
for mirror in "${!MIRROR_COUNTS[@]}"; do
    count=${MIRROR_COUNTS[$mirror]}
    echo "Mirror $mirror selected $count times"
    if [ $count -gt $MAX_COUNT ]; then
        BEST_MIRROR=$mirror
        MAX_COUNT=$count
    fi
done

echo "Selected best mirror: $BEST_MIRROR"

# Update the mirror in sources.list
if [ -n "$BEST_MIRROR" ]; then
    # The output file from apt-select is 'sources.list'
    echo "Fastest mirror found and configuration file created."

    # Backup the current sources.list if a backup does not already exist
    if [ ! -f /etc/apt/sources.list.bak ]; then
        echo "Creating a backup of the current sources.list to sources.list.bak..."
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
    else
        echo "Backup already exists."
    fi

    # Replace the original sources.list with the new one
    if [ -f "$WORKDIR/sources.list" ]; then
        echo "Updating sources.list to use the fastest mirror..."
        mv "$WORKDIR/sources.list" /etc/apt/sources.list
    else
        echo "No sources.list was generated. Check apt-select output for errors."
        deactivate
        exit 1
    fi

    # Clean up and restore original directory
    cd "$CURRENT_DIR"
    rm -rf "$WORKDIR"

    apt-get update -y
    echo "The sources.list has been updated with sources from $BEST_MIRROR."
else
    echo "Failed to determine a fast mirror. Not updating sources.list."
fi

deactivate
deactivate
