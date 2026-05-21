#!/bin/bash

LOG_FILE_OUTPUT="deploy_smart_cities_scenario_output.txt"
exec > >(tee -a "$LOG_FILE_OUTPUT") 2>&1

# Exit immediately if a command fails
set -e

echo "Clearing existing subscribers from the database..."
./install_scripts/unregister_all_subscribers.sh

echo "Rescue Drones"
./install_scripts/register_subscriber.sh --imsi "001017005000101" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 1 --apn "rescue_drones_def_default" --ipv4 "10.60.0.2" --apn "rescue_drones_def_ims" --ipv4 "10.61.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000102" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 2 --apn "rescue_drones_ded_default" --ipv4 "10.62.0.2" --apn "rescue_drones_ded_ims" --ipv4 "10.63.0.2"

echo "Holographic Video Calls"
./install_scripts/register_subscriber.sh --imsi "001017005000201" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 3 --apn "holographic_video_calls_def_default" --ipv4 "10.64.0.2" --apn "holographic_video_calls_def_ims" --ipv4 "10.65.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000202" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 4 --apn "holographic_video_calls_ded_default" --ipv4 "10.66.0.2" --apn "holographic_video_calls_ded_ims" --ipv4 "10.67.0.2"

echo "HD Video Calls"
./install_scripts/register_subscriber.sh --imsi "001017005000301" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 5 --apn "hd_video_calls_def_default" --ipv4 "10.68.0.2" --apn "hd_video_calls_def_ims" --ipv4 "10.69.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000302" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 6 --apn "hd_video_calls_ded_default" --ipv4 "10.70.0.2" --apn "hd_video_calls_ded_ims" --ipv4 "10.71.0.2"

echo "VoIP"
./install_scripts/register_subscriber.sh --imsi "001017005000401" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 7 --apn "voip_def_default" --ipv4 "10.72.0.2" --apn "voip_def_ims" --ipv4 "10.73.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000402" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 7 --sd 8 --apn "voip_ded_default" --ipv4 "10.74.0.2" --apn "voip_ded_ims" --ipv4 "10.75.0.2"

echo "CCTV Cameras"
./install_scripts/register_subscriber.sh --imsi "001017005000501" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 8 --sd 1 --apn "cctv_cameras_def_default" --ipv4 "10.76.0.2" --apn "cctv_cameras_def_ims" --ipv4 "10.77.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000502" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 8 --sd 2 --apn "cctv_cameras_ded_default" --ipv4 "10.78.0.2" --apn "cctv_cameras_ded_ims" --ipv4 "10.79.0.2"

echo "Surveillance Drones"
./install_scripts/register_subscriber.sh --imsi "001017005000601" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 8 --sd 3 --apn "surveillance_drones_def_default" --ipv4 "10.80.0.2" --apn "surveillance_drones_def_ims" --ipv4 "10.81.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000602" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 8 --sd 4 --apn "surveillance_drones_ded_default" --ipv4 "10.82.0.2" --apn "surveillance_drones_ded_ims" --ipv4 "10.83.0.2"

echo "Smart Home Sensors"
./install_scripts/register_subscriber.sh --imsi "001017005000701" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 9 --sd 1 --apn "smart_home_sensors_def_default" --ipv4 "10.84.0.2" --apn "smart_home_sensors_def_ims" --ipv4 "10.85.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000702" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 9 --sd 2 --apn "smart_home_sensors_ded_default" --ipv4 "10.86.0.2" --apn "smart_home_sensors_ded_ims" --ipv4 "10.87.0.2"

echo "Industrial Building Sensors"
./install_scripts/register_subscriber.sh --imsi "001017005000801" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 9 --sd 3 --apn "industrial_building_sensors_def_default" --ipv4 "10.88.0.2" --apn "industrial_building_sensors_def_ims" --ipv4 "10.89.0.2"
./install_scripts/register_subscriber.sh --imsi "001017005000802" --key "00112233445566778899aabbccddeeff" --opc "63BFA50EE6523365FF14C1F45F88737D" --sst 9 --sd 4 --apn "industrial_building_sensors_ded_default" --ipv4 "10.90.0.2" --apn "industrial_building_sensors_ded_ims" --ipv4 "10.91.0.2"

echo "Successfully registered all subscribers. Log file: $LOG_FILE_OUTPUT"
