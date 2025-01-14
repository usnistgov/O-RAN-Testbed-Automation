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
# NIST-developed software is expressly provided 'AS IS.' NIST MAKES NO WARRANTY
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

SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR"

# Exit immediately if a command fails
set -e

if [ ! -d "rappmanager" ]; then
    ./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/nonrtric/plt/rappmanager.git rappmanager
fi

cd rappmanager/sample-rapp-generator
if [ ! -f generate.previous.sh ]; then
    mv generate.sh generate.previous.sh
fi
cp "$PARENT_DIR/install_patch_files/rappmanager/sample-rapp-generator/generate.sh" .

cd "$PARENT_DIR"
mkdir -p rApps

cd rappmanager/sample-rapp-generator

if [ -d rapp-hello-world ]; then
    echo
    echo "Generating Hello World rApp binary (rapp-hello-world.csar)..."
    ./generate.sh rapp-hello-world
    echo "Moving rApp binary to rApps directory..."
    cp rapp-hello-world.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-hello-world, skipping."
fi

if [ -d rapp-hello-world-sme-invoker ]; then
    echo
    echo "Generating Hello World SME Invoker rApp binary (rapp-hello-world-sme-invoker.csar)..."
    ./generate.sh rapp-hello-world-sme-invoker
    echo "Moving rApp binary to rApps directory..."
    cp rapp-hello-world-sme-invoker.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-hello-world-sme-invoker, skipping."
fi

if [ -d rapp-kserve ]; then
    echo
    echo "Generating KServe rApp binary (rapp-kserve.csar)..."
    ./generate.sh rapp-kserve
    echo "Moving rApp binary to rApps directory..."
    cp rapp-kserve.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-kserve, skipping."
fi

if [ -d rapp-sample-ics-consumer ]; then
    echo
    echo "Generating Sample ICS Consumer rApp binary (rapp-sample-ics-consumer.csar)..."
    ./generate.sh rapp-sample-ics-consumer
    echo "Moving rApp binary to rApps directory..."
    cp rapp-sample-ics-consumer.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-sample-ics-consumer, skipping."
fi

if [ -d rapp-sample-ics-producer ]; then
    echo
    echo "Generating Sample ICS Producer rApp binary (rapp-sample-ics-producer.csar)..."
    ./generate.sh rapp-sample-ics-producer
    echo "Moving rApp binary to rApps directory..."
    cp rapp-sample-ics-producer.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-sample-ics-producer, skipping."
fi

if [ -d rapp-simple-ics-consumer ]; then
    echo
    echo "Generating Simple ICS Consumer rApp binary (rapp-simple-ics-consumer.csar)..."
    ./generate.sh rapp-simple-ics-consumer
    echo "Moving rApp binary to rApps directory..."
    cp rapp-simple-ics-consumer.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-simple-ics-consumer, skipping."
fi

if [ -d rapp-simple-ics-producer ]; then
    echo
    echo "Generating Simple ICS Producer rApp binary (rapp-simple-ics-producer.csar)..."
    ./generate.sh rapp-simple-ics-producer
    echo "Moving rApp binary to rApps directory..."
    cp rapp-simple-ics-producer.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-simple-ics-producer, skipping."
fi

if [ -d rapp-simple-ics-consumer ]; then
    echo
    echo "Generating Simple ICS Producer Consumer rApp binary (rapp-simple-ics-consumer.csar)..."
    ./generate.sh rapp-simple-ics-consumer
    echo "Moving rApp binary to rApps directory..."
    cp rapp-simple-ics-consumer.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-simple-ics-consumer, skipping."
fi

if [ -d rapp-all ]; then
    echo
    echo "Generating rApp All binary (rapp-all.csar)..."
    ./generate.sh rapp-all
    echo "Moving rApp binary to rApps directory..."
    cp rapp-all.csar "$PARENT_DIR/rApps"
else
    echo "Could not find rappmanager/sample-rapp-generator/rapp-all, skipping."
fi

echo
echo "Successfully generated sample rApp binaries."
