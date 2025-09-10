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
cd "$(dirname "$SCRIPT_DIR")"

cd 5G_Core_Network
./install_scripts/git_clone.sh https://github.com/open5gs/open5gs.git
cd ..

cd User_Equipment
./install_scripts/git_clone.sh https://github.com/srsran/srsRAN_4G.git
./install_scripts/git_clone.sh https://github.com/zeromq/libzmq.git
./install_scripts/git_clone.sh https://github.com/zeromq/czmq.git
cd ..

cd Next_Generation_Node_B
./install_scripts/git_clone.sh https://github.com/srsran/srsRAN_Project.git
cd ..

cd RAN_Intelligent_Controllers/Near-Real-Time-RIC
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/sim/e2-interface.git
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/appmgr.git
mkdir -p xApps
cd xApps
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-go.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-python.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/hw-rust.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/kpimon-go.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ad-cell.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ad.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/qp.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/rc.git
./../install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-app/ts.git

cd ../../..

cd RAN_Intelligent_Controllers/Non-Real-Time-RIC
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/it/dep.git
cd dep
git restore --source=HEAD :/
cd ..
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm.git dep/ranpm
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git dep/ric-dep
./install_scripts/git_clone.sh https://github.com/onap/multicloud-k8s.git dep/smo-install/multicloud-k8s
./install_scripts/git_clone.sh https://gerrit.onap.org/r/oom.git dep/smo-install/onap_oom
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel.git
./install_scripts/git_clone.sh https://gerrit.o-ran-sc.org/r/nonrtric/plt/rappmanager.git
mkdir -p rApps
cd ../..

cd OpenAirInterface_Testbed/5G_Core_Network
./install_scripts/git_clone.sh https://github.com/open5gs/open5gs.git
cd ../..

cd OpenAirInterface_Testbed/User_Equipment
./install_scripts/git_clone.sh https://gitlab.eurecom.fr/oai/openairinterface5g.git
cd ../..

cd OpenAirInterface_Testbed/Next_Generation_Node_B
ln -s "../User_Equipment/openairinterface5g" openairinterface5g
cd ../..

cd OpenAirInterface_Testbed/RAN_Intelligent_Controllers/Flexible-RIC
./install_scripts/git_clone.sh https://github.com/swig/swig.git
./install_scripts/git_clone.sh https://gitlab.eurecom.fr/mosaic5g/flexric.git
cd ../..

echo "Repositories were cloned successfully."
