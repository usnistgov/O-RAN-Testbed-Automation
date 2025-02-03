@echo off

REM NIST-developed software is provided by NIST as a public service. You may use,
REM copy, and distribute copies of the software in any medium, provided that you
REM keep intact this entire notice. You may improve, modify, and create derivative
REM works of the software or any portion of the software, and you may copy and
REM distribute such modifications or works. Modified works should carry a notice
REM stating that you changed the software and should note the date and nature of
REM any such change. Please explicitly acknowledge the National Institute of
REM Standards and Technology as the source of the software.
REM
REM NIST-developed software is expressly provided AS IS. NIST MAKES NO WARRANTY
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

REM This script will download the 5G_Core_Network, gNodeB, User_Equipment, and RAN_Intelligent_Controllers repositories for analyzing the source code without requiring a full testbed build and installation.

echo Script: %~f0...

REM Change to the parent directory of the script
cd %~dp0..

if exist "5G_Core_Network\open5gs" rmdir /s /q "5G_Core_Network\open5gs"
cd 5G_Core_Network
git clone https://github.com/open5gs/open5gs.git
cd open5gs
git checkout 81f69b436c5b48c38b7547d198e74e04e7677773
cd ..\..

if exist "User_Equipment\srsRAN_4G" rmdir /s /q "User_Equipment\srsRAN_4G"
cd User_Equipment
git clone https://github.com/srsran/srsRAN_4G.git
cd srsRAN_4G
git checkout ec29b0c1ff79cebcbe66caa6d6b90778261c42b8
cd ..\..

if exist "User_Equipment\libzmq" rmdir /s /q "User_Equipment\libzmq"
cd User_Equipment
git clone https://github.com/zeromq/libzmq.git
cd libzmq
git checkout 34f7fa22022bed9e0e390ed3580a1c83ac4a2834
cd ..\..

if exist "User_Equipment\czmq" rmdir /s /q "User_Equipment\czmq"
cd User_Equipment
git clone https://github.com/zeromq/czmq.git
cd czmq
git checkout 5b5c640248dfb6e9a9a612cfad16d8c019e5702c
cd ..\..

if exist "Next_Generation_Node_B\srsRAN_Project" rmdir /s /q "Next_Generation_Node_B\srsRAN_Project"
cd Next_Generation_Node_B
git clone https://github.com/srsran/srsRAN_Project.git
cd srsRAN_Project
git checkout cc2869f967adfd8d33f9d1440839bf5f1b282998
cd ..\..

if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\ric-dep" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\ric-dep"
cd RAN_Intelligent_Controllers\Near-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git
cd ric-dep
git checkout 505e5efb5f40706adccdfdc7a5289456cd01fe8a
cd ..\..\..

if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\e2-interface" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\e2-interface"
cd RAN_Intelligent_Controllers\Near-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/sim/e2-interface.git
cd e2-interface
git checkout da6f82f286cdbb38af1178f82f85877b12c2f85b
cd ..\..\..

if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\appmgr" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\appmgr"
cd RAN_Intelligent_Controllers\Near-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/ric-plt/appmgr.git
cd appmgr
git checkout 4c05932dce72e98db23eaff2b72b58816e1f2d55
cd ..\..\..

if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\xApps\hw-go" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\xApps\hw-go"
cd RAN_Intelligent_Controllers\Near-Real-Time-RIC\xApps
git clone https://gerrit.o-ran-sc.org/r/ric-app/hw-go.git
cd hw-go
git checkout 3a0d348e429ea0f3f3d2a1d5eb54ec8758d1a262
cd ..\..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/it/dep.git
cd dep
git checkout 60372089116269f82038c0fe38a02acbc51fb269
git restore --source=HEAD :/
cd ..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\ranpm" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\ranpm"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep
git clone https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm.git
cd ranpm
git checkout dbb29d3eb620b0ed223510590030a9a4a3c73d50
cd ..\..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\ric-dep" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\ric-dep"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep
git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep.git
cd ric-dep
git checkout 505e5efb5f40706adccdfdc7a5289456cd01fe8a
cd ..\..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\smo-install\multicloud-k8s" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\smo-install\multicloud-k8s"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\smo-install
git clone https://github.com/onap/multicloud-k8s.git
cd multicloud-k8s
git checkout 8bea0a13c223aff43f98f0cb6426379bb23e8894
cd ..\..\..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\smo-install\onap_oom" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\smo-install\onap_oom"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep\smo-install
git clone https://gerrit.onap.org/r/oom.git
cd onap_oom
git checkout 8009e77c8cdc3e33a7063df176eb9d0f0b805014
cd ..\..\..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\nonrtric-controlpanel" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\nonrtric-controlpanel"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/portal/nonrtric-controlpanel.git
cd nonrtric-controlpanel
git checkout 15bdaf8f25dca54e3a52ad30d69fa2eb1d59ce48
cd ..\..\..

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\rappmanager" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\rappmanager"
cd RAN_Intelligent_Controllers\Non-Real-Time-RIC
git clone https://gerrit.o-ran-sc.org/r/nonrtric/plt/rappmanager.git
cd rappmanager
git checkout ffd5b45b53572ae42fbc22510bcbe3ad8883b86f
cd ..\..\..


cd RAN_Intelligent_Controllers\Non-Real-Time-RIC
mkdir rApps
cd ..\..

echo Repositories were cloned successfully.
pause

