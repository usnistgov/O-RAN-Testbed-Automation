: '
REM NIST-developed software is provided by NIST as a public service. You may use,
REM copy, and distribute copies of the software in any medium, provided that you
REM keep intact this entire notice. You may improve, modify, and create derivative
REM  works of the software or any portion of the software, and you may copy and
REM distribute such modifications or works. Modified works should carry a notice
REM stating that you changed the software and should note the date and nature of
REM any such change. Please explicitly acknowledge the National Institute of
REM Standards and Technology as the source of the software.
REM
REM NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
REM OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
REM INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
REM FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
REM NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
REM UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
REM NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
REM THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
REM RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
REM
REM You are solely responsible for determining the appropriateness of using and
REM distributing the software and you assume all risks associated with its use,
REM including but not limited to the risks and costs of program errors, compliance
REM with applicable laws, damage to or loss of data, programs or equipment, and
REM the unavailability or interruption of operation. This software is not intended
REM to be used in any situation where a failure could cause risk of injury or
REM damage to property. The software developed by NIST employees is not subject to
REM copyright protection within the United States.
'

: '
REM This Linux shell/Windows batch script will download the 5G_Core_Network, gNodeB, User_Equipment and RAN_Intelligent_Controllers repositories for analyzing the source code without requiring a full testbed build and installation.
@echo off
'

cd ..

cd 5G_Core_Network
git clone https://github.com/open5gs/open5gs.git open5gs
cd ..

cd User_Equipment
git clone https://github.com/srsran/srsRAN_4G.git
git clone https://github.com/zeromq/libzmq.git
git clone https://github.com/zeromq/czmq.git
cd ..

cd Next_Generation_Node_B
git clone https://github.com/srsran/srsRAN_Project.git
cd ..

cd RAN_Intelligent_Controllers/Near-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep -b j-release
git clone https://gerrit.o-ran-sc.org/r/sim/e2-interface
git clone https://gerrit.o-ran-sc.org/r/ric-plt/appmgr
mkdir xApps
cd xApps
git clone https://gerrit.o-ran-sc.org/r/ric-app/hw-go
cd ..
cd ..
cd ..

cd RAN_Intelligent_Controllers/Non-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/it/dep
cd dep
git restore --source=HEAD :/
cd ..
git clone https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm -b j-release dep/ranpm
git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep -b j-release dep/ric-dep
git clone https://github.com/onap/multicloud-k8s.git dep/smo-install/multicloud-k8s
git clone https://gerrit.onap.org/r/oom dep/smo-install/onap_oom
git clone https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel -b j-release
cd ..
cd ..

echo "Repositories were cloned successfully."

: '
PAUSE
'
