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

# This script will download the 5G_Core_Network, gNodeB, User_Equipment and RAN_Intelligent_Controllers repositories for analyzing the source code without requiring a full testbed build and installation.

APTVARS="NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 DEBIAN_FRONTEND=noninteractive"
if ! command -v realpath &>/dev/null; then
    echo "Package \"coreutils\" not found, installing..."
    sudo env $APTVARS apt-get install -y coreutils
fi

echo "# Script: $(realpath "$0")..."

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# Define the path to the JSON file containing commit hashes
JSON_FILE="../commit_hashes.json"

# Start the batch file output
echo "REM NIST-developed software is provided by NIST as a public service. You may use," >download_dependency_repositories.bat
echo "REM copy, and distribute copies of the software in any medium, provided that you" >>download_dependency_repositories.bat
echo "REM keep intact this entire notice. You may improve, modify, and create derivative" >>download_dependency_repositories.bat
echo "REM works of the software or any portion of the software, and you may copy and" >>download_dependency_repositories.bat
echo "REM distribute such modifications or works. Modified works should carry a notice" >>download_dependency_repositories.bat
echo "REM stating that you changed the software and should note the date and nature of" >>download_dependency_repositories.bat
echo "REM any such change. Please explicitly acknowledge the National Institute of" >>download_dependency_repositories.bat
echo "REM Standards and Technology as the source of the software." >>download_dependency_repositories.bat
echo "REM" >>download_dependency_repositories.bat
echo "REM NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY" >>download_dependency_repositories.bat
echo "REM OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW," >>download_dependency_repositories.bat
echo "REM INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY," >>download_dependency_repositories.bat
echo "REM FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST" >>download_dependency_repositories.bat
echo "REM NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE" >>download_dependency_repositories.bat
echo "REM UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES" >>download_dependency_repositories.bat
echo "REM NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR" >>download_dependency_repositories.bat
echo "REM THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY," >>download_dependency_repositories.bat
echo "REM RELIABILITY, OR USEFULNESS OF THE SOFTWARE." >>download_dependency_repositories.bat
echo "REM" >>download_dependency_repositories.bat
echo "REM You are solely responsible for determining the appropriateness of using and" >>download_dependency_repositories.bat
echo "REM distributing the software and you assume all risks associated with its use," >>download_dependency_repositories.bat
echo "REM including but not limited to the risks and costs of program errors, compliance" >>download_dependency_repositories.bat
echo "REM with applicable laws, damage to or loss of data, programs or equipment, and" >>download_dependency_repositories.bat
echo "REM the unavailability or interruption of operation. This software is not intended" >>download_dependency_repositories.bat
echo "REM to be used in any situation where a failure could cause risk of injury or" >>download_dependency_repositories.bat
echo "REM damage to property. The software developed by NIST employees is not subject to" >>download_dependency_repositories.bat
echo "REM copyright protection within the United States." >>download_dependency_repositories.bat
echo "" >>download_dependency_repositories.bat
echo "@echo off" >>download_dependency_repositories.bat
echo "" >>download_dependency_repositories.bat
echo "REM This is an automatically generated script to download the testbed repositories to analyze the source code without requiring a full testbed build and installation." >>download_dependency_repositories.bat
echo "REM WARNING: Please do not edit this file manually since it is overwritten with the script: ./Additional_Scripts/generate_download_dependency_repositories.bat.sh" >>download_dependency_repositories.bat
echo "" >>download_dependency_repositories.bat
echo "echo Script: %~f0..." >>download_dependency_repositories.bat
echo "" >>download_dependency_repositories.bat

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq to process JSON files..."
    sudo env $APTVARS apt-get install -y jq
fi

# Function to generate the git clone and git checkout commands
function generate_commands() {
    local URL="$1"
    local CLONE_PATH="$2"
    local SUBDIRECTORY="$3"

    local DEPTH_COUNT=$(tr -cd '\\' <<<"$CLONE_PATH" | wc -c)

    # Fetch branch and commit using jq, if a commit hash is found, checkout to it
    local BRANCH=$(jq -r ".[\"$URL\"][0]" $JSON_FILE)
    local COMMIT=$(jq -r ".[\"$URL\"][1]" $JSON_FILE)

    # Reset the current directory
    echo "cd %~dp0.." >>download_dependency_repositories.bat

    # Generate commands for batch script
    echo "if exist \"$CLONE_PATH\\$SUBDIRECTORY\" rmdir /s /q \"$CLONE_PATH\\$SUBDIRECTORY\"" >>download_dependency_repositories.bat
    echo "cd $CLONE_PATH" >>download_dependency_repositories.bat
    echo "git clone $URL" >>download_dependency_repositories.bat

    APPEND_LINE=""
    if [[ "$SUBDIRECTORY" == "dep" ]]; then
        APPEND_LINE+="git restore --source=HEAD :/"
    fi

    if [[ "$COMMIT" != "null" && "$COMMIT" != "" ]]; then
        echo "cd $SUBDIRECTORY" >>download_dependency_repositories.bat
        echo "git checkout $COMMIT" >>download_dependency_repositories.bat
        if [ ! -z "$APPEND_LINE" ]; then
            echo "$APPEND_LINE" >>download_dependency_repositories.bat
        fi
        DEPTH_COUNT=$((DEPTH_COUNT + 1))
    elif [[ "$BRANCH" != "null" && "$BRANCH" != "" ]]; then
        echo "cd $SUBDIRECTORY" >>download_dependency_repositories.bat
        echo "git checkout $BRANCH" >>download_dependency_repositories.bat
        if [ ! -z "$APPEND_LINE" ]; then
            echo "$APPEND_LINE" >>download_dependency_repositories.bat
        fi
        DEPTH_COUNT=$((DEPTH_COUNT + 1))
    else
        if [ ! -z "$APPEND_LINE" ]; then
            echo "cd $SUBDIRECTORY" >>download_dependency_repositories.bat
            echo "$APPEND_LINE" >>download_dependency_repositories.bat
            DEPTH_COUNT=$((DEPTH_COUNT + 1))
        fi
    fi

    # Calculate the number of directory levels to navigate back up to the original directory
    local BACK_COMMAND="cd .."
    while [ $DEPTH_COUNT -gt 0 ]; do
        if [ $DEPTH_COUNT -gt 0 ]; then
            BACK_COMMAND+="\\"
        fi
        BACK_COMMAND+=".."
        let DEPTH_COUNT--
    done

    echo "$BACK_COMMAND" >>download_dependency_repositories.bat
    echo "" >>download_dependency_repositories.bat
}

# Using the function to generate commands for each repository in the blueprint testbed
echo "REM Change to the parent directory of the script" >>download_dependency_repositories.bat
generate_commands "https://github.com/open5gs/open5gs.git" "5G_Core_Network" "open5gs"
generate_commands "https://github.com/srsran/srsRAN_4G.git" "User_Equipment" "srsRAN_4G"
generate_commands "https://github.com/zeromq/libzmq.git" "User_Equipment" "libzmq"
generate_commands "https://github.com/zeromq/czmq.git" "User_Equipment" "czmq"
generate_commands "https://github.com/srsran/srsRAN_Project.git" "Next_Generation_Node_B" "srsRAN_Project"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC" "ric-dep"
generate_commands "https://gerrit.o-ran-sc.org/r/sim/e2-interface.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC" "e2-interface"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-plt/appmgr.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC" "appmgr"

echo "cd RAN_Intelligent_Controllers\\Near-Real-Time-RIC" >>download_dependency_repositories.bat
echo "mkdir xApps" >>download_dependency_repositories.bat
echo "cd ..\\.." >>download_dependency_repositories.bat
echo "" >>download_dependency_repositories.bat
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/hw-go.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "hw-go"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/hw-python.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "hw-python"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/hw-rust.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "hw-rust"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/kpimon-go.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "kpimon-go"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/ad-cell.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "ad-cell"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/ad.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "ad"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/qp.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "qp"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/rc.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "rc"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-app/ts.git" "RAN_Intelligent_Controllers\\Near-Real-Time-RIC\\xApps" "ts"

# O-RAN SC Non-RT RIC repositories
generate_commands "https://gerrit.o-ran-sc.org/r/it/dep.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC" "dep"
generate_commands "https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC\\dep" "ranpm"
generate_commands "https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC\\dep" "ric-dep"
generate_commands "https://github.com/onap/multicloud-k8s.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC\\dep\\smo-install" "multicloud-k8s"
generate_commands "https://gerrit.onap.org/r/oom.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC\\dep\\smo-install" "onap_oom"
generate_commands "https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC" "nonrtric-controlpanel"
generate_commands "https://gerrit.o-ran-sc.org/r/nonrtric/plt/rappmanager.git" "RAN_Intelligent_Controllers\\Non-Real-Time-RIC" "rappmanager"
echo "cd RAN_Intelligent_Controllers\\Non-Real-Time-RIC" >>download_dependency_repositories.bat
echo "mkdir rApps" >>download_dependency_repositories.bat
echo "cd ..\\.." >>download_dependency_repositories.bat

# OpenAirInterface testbed repositories
generate_commands "https://github.com/open5gs/open5gs.git" "OpenAirInterface_Testbed\\5G_Core_Network" "open5gs"
generate_commands "https://gitlab.eurecom.fr/oai/openairinterface5g.git" "OpenAirInterface_Testbed\\User_Equipment" "openairinterface5g"
echo "cd OpenAirInterface_Testbed\\Next_Generation_Node_B" >>download_dependency_repositories.bat
echo "mklink /D openairinterface5g ..\\User_Equipment\\openairinterface5g" >>download_dependency_repositories.bat
echo "cd ..\\.." >>download_dependency_repositories.bat
echo "" >>download_dependency_repositories.bat
generate_commands "https://github.com/swig/swig.git" "OpenAirInterface_Testbed\\RAN_Intelligent_Controllers\\Flexible-RIC" "swig"
generate_commands "https://gitlab.eurecom.fr/mosaic5g/flexric.git" "OpenAirInterface_Testbed\\RAN_Intelligent_Controllers\\Flexible-RIC" "flexric"

echo "" >>download_dependency_repositories.bat
echo "echo Repositories were cloned successfully." >>download_dependency_repositories.bat
echo "pause" >>download_dependency_repositories.bat

echo "Windows batch file 'download_dependency_repositories.bat' has been generated."
