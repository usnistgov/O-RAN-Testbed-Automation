: '
REM This batch script will download the 5G_Core, gNodeB, User_Equipment and RAN_Intelligent_Controller repositories for analyzing the source code without requiring a full testbed build and installation.
'

cd 5G_Core
git clone https://github.com/open5gs/open5gs.git
cd ..

cd gNodeB
git clone https://github.com/srsran/srsRAN_Project.git
git clone https://github.com/zeromq/libzmq.git
git clone https://github.com/zeromq/czmq.git
cd ..

cd User_Equipment
git clone https://github.com/srsran/srsRAN_4G.git
cd ..

cd RAN_Intelligent_Controller
git clone https://gerrit.o-ran-sc.org/r/ric-plt/ric-dep -b j-release
git clone https://gerrit.o-ran-sc.org/r/sim/e2-interface
git clone https://gerrit.o-ran-sc.org/r/ric-plt/appmgr
mkdir xApps
cd xApps
git clone https://gerrit.o-ran-sc.org/r/ric-app/hw-go
cd ..
cd ..

echo Repositories were cloned successfully.

if [ "%OS%" == "Windows_NT" ]; then pause; fi
