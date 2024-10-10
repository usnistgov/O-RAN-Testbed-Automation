@echo off
REM Check if Git is installed
git --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Git is not installed, please install Git and try again.
    exit /b
)


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
pause
