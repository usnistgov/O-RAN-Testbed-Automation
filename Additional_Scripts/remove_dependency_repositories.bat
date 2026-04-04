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

@echo off

REM This script will remove the untracked 5G_Core_Network, Next_Generation_Node_B, User_Equipment and RAN_Intelligent_Controllers repositories that were downloaded.

echo Script: %~f0...

REM Change to the parent directory of the script
cd %~dp0..

REM NIST-developed software is provided by NIST as a public service. You may use,
REM copy, and distribute copies of the software in any medium, provided that you
REM keep intact this entire notice. You may improve, modify, and create derivative
REM works of the software or any portion of the software, and you may copy and
REM distribute such modifications or works. Modified works should carry a notice
REM stating that you changed the software and should note the date and nature of
REM any such change. Please explicitly acknowledge the National Institute of
REM Standards and Technology as the source of the software.
REM NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
REM OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
REM INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
REM FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
REM NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
REM UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
REM NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
REM THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
REM RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
REM You are solely responsible for determining the appropriateness of using and
REM distributing the software and you assume all risks associated with its use,
REM including but not limited to the risks and costs of program errors, compliance
REM with applicable laws, damage to or loss of data, programs or equipment, and
REM the unavailability or interruption of operation. This software is not intended
REM to be used in any situation where a failure could cause risk of injury or
REM damage to property. The software developed by NIST employees is not subject to
REM copyright protection within the United States.

REM This script will remove the untracked 5G_Core_Network, Next_Generation_Node_B, User_Equipment and RAN_Intelligent_Controllers repositories that were downloaded.


echo "# Script: $(realpath "$0")..."

REM Main Testbed Repositories
if exist "5G_Core_Network\open5gs" rmdir /s /q "5G_Core_Network\open5gs"
if exist "5G_Core_Network\logs" rmdir /s /q "5G_Core_Network\logs"
if exist "5G_Core_Network\configs" rmdir /s /q "5G_Core_Network\configs"
if exist "5G_Core_Network\install_time.txt" del /f /q "5G_Core_Network\install_time.txt"

if exist "5G_Core_Network\Additional_Cores_5GDeploy\5gdeploy" rmdir /s /q "5G_Core_Network\Additional_Cores_5GDeploy\5gdeploy"
if exist "5G_Core_Network\Additional_Cores_5GDeploy\compose" rmdir /s /q "5G_Core_Network\Additional_Cores_5GDeploy\compose"
if exist "5G_Core_Network\Additional_Cores_5GDeploy\logs" rmdir /s /q "5G_Core_Network\Additional_Cores_5GDeploy\logs"
if exist "5G_Core_Network\Additional_Cores_5GDeploy\configs" rmdir /s /q "5G_Core_Network\Additional_Cores_5GDeploy\configs"
if exist "5G_Core_Network\Additional_Cores_5GDeploy\install_time.txt" del /f /q "5G_Core_Network\Additional_Cores_5GDeploy\install_time.txt"

if exist "User_Equipment\srsRAN_4G" rmdir /s /q "User_Equipment\srsRAN_4G"
if exist "User_Equipment\czmq" rmdir /s /q "User_Equipment\czmq"
if exist "User_Equipment\libzmq" rmdir /s /q "User_Equipment\libzmq"
if exist "User_Equipment\logs" rmdir /s /q "User_Equipment\logs"
if exist "User_Equipment\configs" rmdir /s /q "User_Equipment\configs"
if exist "User_Equipment\install_time.txt" del /f /q "User_Equipment\install_time.txt"

if exist "Next_Generation_Node_B\ocudu" rmdir /s /q "Next_Generation_Node_B\ocudu"
if exist "Next_Generation_Node_B\ocudu_o1_adapter" rmdir /s /q "Next_Generation_Node_B\ocudu_o1_adapter"
if exist "Next_Generation_Node_B\ocudu_netconf" rmdir /s /q "Next_Generation_Node_B\ocudu_netconf"
if exist "Next_Generation_Node_B\zmq_broker" rmdir /s /q "Next_Generation_Node_B\zmq_broker"
if exist "Next_Generation_Node_B\czmq" rmdir /s /q "Next_Generation_Node_B\czmq"
if exist "Next_Generation_Node_B\libzmq" rmdir /s /q "Next_Generation_Node_B\libzmq"
if exist "Next_Generation_Node_B\logs" rmdir /s /q "Next_Generation_Node_B\logs"
if exist "Next_Generation_Node_B\configs" rmdir /s /q "Next_Generation_Node_B\configs"
if exist "Next_Generation_Node_B\install_time.txt" del /f /q "Next_Generation_Node_B\install_time.txt"

if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\ric-dep" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\ric-dep"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\appmgr" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\appmgr"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\e2-interface" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\e2-interface"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\charts" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\charts"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\xApps" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\xApps"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\logs" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\logs"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\influxdb" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\influxdb"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\influxdb_auth_token.json" del /f /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\influxdb_auth_token.json"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\additional_scripts\pod_pcaps" rmdir /s /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\additional_scripts\pod_pcaps"
if exist "RAN_Intelligent_Controllers\Near-Real-Time-RIC\install_time.txt" del /f /q "RAN_Intelligent_Controllers\Near-Real-Time-RIC\install_time.txt"

if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\dep"
if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\rappmanager" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\rappmanager"
if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\nonrtric-controlpanel" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\nonrtric-controlpanel"
if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\rApps" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\rApps"
if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\logs" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\logs"
if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\configs" rmdir /s /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\configs"
if exist "RAN_Intelligent_Controllers\Non-Real-Time-RIC\install_time.txt" del /f /q "RAN_Intelligent_Controllers\Non-Real-Time-RIC\install_time.txt"

REM OpenAirInterface_Testbed Repositories
if exist "OpenAirInterface_Testbed\5G_Core_Network\open5gs" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\open5gs"
if exist "OpenAirInterface_Testbed\5G_Core_Network\logs" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\logs"
if exist "OpenAirInterface_Testbed\5G_Core_Network\configs" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\configs"
if exist "OpenAirInterface_Testbed\5G_Core_Network\install_time.txt" del /f /q "OpenAirInterface_Testbed\5G_Core_Network\install_time.txt"

if exist "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\5gdeploy" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\5gdeploy"
if exist "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\compose" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\compose"
if exist "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\logs" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\logs"
if exist "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\configs" rmdir /s /q "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\configs"
if exist "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\install_time.txt" del /f /q "OpenAirInterface_Testbed\5G_Core_Network\Additional_Cores_5GDeploy\install_time.txt"

if exist "OpenAirInterface_Testbed\User_Equipment\openairinterface5g" rmdir /s /q "OpenAirInterface_Testbed\User_Equipment\openairinterface5g"
if exist "OpenAirInterface_Testbed\User_Equipment\logs" rmdir /s /q "OpenAirInterface_Testbed\User_Equipment\logs"
if exist "OpenAirInterface_Testbed\User_Equipment\configs" rmdir /s /q "OpenAirInterface_Testbed\User_Equipment\configs"
if exist "OpenAirInterface_Testbed\User_Equipment\install_time.txt" del /f /q "OpenAirInterface_Testbed\User_Equipment\install_time.txt"

if exist "OpenAirInterface_Testbed\Next_Generation_Node_B\openairinterface5g" rmdir /s /q "OpenAirInterface_Testbed\Next_Generation_Node_B\openairinterface5g"
if exist "OpenAirInterface_Testbed\Next_Generation_Node_B\o1-adapter" rmdir /s /q "OpenAirInterface_Testbed\Next_Generation_Node_B\o1-adapter"
if exist "OpenAirInterface_Testbed\Next_Generation_Node_B\logs" rmdir /s /q "OpenAirInterface_Testbed\Next_Generation_Node_B\logs"
if exist "OpenAirInterface_Testbed\Next_Generation_Node_B\configs" rmdir /s /q "OpenAirInterface_Testbed\Next_Generation_Node_B\configs"
if exist "OpenAirInterface_Testbed\Next_Generation_Node_B\install_time.txt" del /f /q "OpenAirInterface_Testbed\Next_Generation_Node_B\install_time.txt"

if exist "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\swig" rmdir /s /q "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\swig"
if exist "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\flexric" rmdir /s /q "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\flexric"
if exist "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\logs" rmdir /s /q "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\logs"
if exist "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\configs" rmdir /s /q "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\configs"
if exist "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\install_time.txt" del /f /q "OpenAirInterface_Testbed\RAN_Intelligent_Controllers\Flexible-RIC\install_time.txt"

echo "Repositories were removed successfully."
