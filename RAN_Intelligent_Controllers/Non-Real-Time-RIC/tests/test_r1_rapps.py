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

from kubernetes import client, config
import json
import os
import pytest
import requests

global rapp_id, rapp_file_name
rapp_id = "icsconsumer"
#rapp_file_name = "rapp-hello-world.csar"
rapp_file_name = "rapp-simple-ics-consumer.csar"

config.load_kube_config()
v1 = client.CoreV1Api()

# R1 RAppManager API: https://docs.o-ran-sc.org/projects/o-ran-sc-nonrtric-plt-rappmanager/en/stable/api-docs.html

################################################################################
# Test that the rApp Manager pod is running
################################################################################
def test_pod_status():
    global rappmgr_pod_name, rappmgr_ip, rappmgr_port
    rappmgr_pod_name = v1.list_namespaced_pod('nonrtric', label_selector='app=nonrtric-rappmanager').items[0].metadata.name
    rappmgr_ip = v1.read_namespaced_pod(rappmgr_pod_name, 'nonrtric').status.pod_ip
    rappmgr_port=8080
    
    assert rappmgr_pod_name is not None, 'rApp Manager pod not found'
    assert rappmgr_ip is not None, 'rApp Manager IP not found'
    assert rappmgr_port is not None, 'rApp Manager port not found'
    
    print(f'IP of {rappmgr_pod_name}: {rappmgr_ip}')
    print(f'Port of {rappmgr_pod_name}: {rappmgr_port}')

# Remove the testing rApp if it exists
def remove_test_rapp_if_exists(rapp_id, file_name):
    global rappmgr_ip, rappmgr_port
    # First check if an xApp with the same file name exists
    service_status = requests.get(f'http://{rappmgr_ip}:{rappmgr_port}/rapps')
    print(f'Console command: curl -X GET http://{rappmgr_ip}:{rappmgr_port}/rapps')
    if service_status.status_code == 200:
        json_response = json.loads(service_status.text)
        for rapp in json_response:
            if "packageName" in rapp and rapp["packageName"] == file_name:
                rapp_id = rapp["name"]
                print(f"Found testing rapp (id: {rapp_id}), removing...")
                remove_rapp = requests.delete(f'http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
                print(f'Console command: curl -X DELETE http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
                if remove_rapp.status_code != 200:
                    print(f'Failed to remove rApp: {remove_rapp.text}, status code: {remove_rapp.status_code}')
    
    # Next, check if an xApp with the same ID exists
    service_status = requests.get(f'http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
    print(f'Console command: curl -X GET http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
    if service_status.status_code == 200:
        print(f"Found testing rapp (id: {rapp_id}), removing...")
        remove_rapp = requests.delete(f'http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
        print(f'Console command: curl -X DELETE http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
        if remove_rapp.status_code != 200:
            print(f'Failed to remove rApp: {remove_rapp.text}, status code: {remove_rapp.status_code}')
    

################################################################################
# Test the creation of a testing rApp
################################################################################
def test_rapp_creation():
    global rappmgr_ip, rappmgr_port, rapp_id, rapp_file_name
    remove_test_rapp_if_exists(rapp_id, rapp_file_name)

    print("Creating testing rApp...")
    rapp_dir_original = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "rApps")
    rapp_dir = "/"
    
    os.system(f'sudo rm -rf {os.path.join(rapp_dir, rapp_file_name)}')
    os.system(f'sudo cp {os.path.join(rapp_dir_original, rapp_file_name)} {rapp_dir}')

    rapp_binary_path = os.path.join(rapp_dir, rapp_file_name)

    with open(rapp_binary_path, 'rb') as file:
        files = {'file': (rapp_binary_path, file, 'application/octet-stream')}
        create_rapp = requests.post(f'http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}', files=files)

    print(f'Console command: curl -X POST http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id} -F "file=@{rapp_binary_path}"')
    assert create_rapp.status_code == 202, f'Create rApp status code: {create_rapp.status_code}'

    # Clean up the testing rApp file
    # os.system(f'sudo rm -rf {os.path.join(rapp_dir, rapp_file_name)}')

##################################################################################
# Test the fetching of the rApp information
##################################################################################
def test_rapp_info():
    global rappmgr_ip, rappmgr_port, rapp_id, rapp_file_name
    service_status = requests.get(f'http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
    print(f'Console command: curl -X GET http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}')
    assert service_status.status_code == 200, f'Service status code: {service_status.status_code}'
    
    json_response = json.loads(service_status.text)
    assert type(json_response) is dict, f'Response is not a dictionary: {service_status.text}'
    print(f'rApp information: {json_response}')

    assert "name" in json_response, f'rApp name not found: {json_response}'
    assert json_response["name"] == rapp_id, f'rApp name mismatch: {json_response}'

    assert "packageName" in json_response, f'rApp package name not found: {json_response}'
    assert json_response["packageName"] == rapp_file_name, f'rApp package name mismatch: {json_response}'

    assert "state" in json_response, f'rApp state not found: {json_response}'
    assert json_response["state"] == "COMMISSIONED", f'rApp state mismatch: {json_response}'

################################################################################
# Test that the rApp Manager status is success
################################################################################
def test_rapps_list():
    global rappmgr_ip, rappmgr_port
    service_status = requests.get(f'http://{rappmgr_ip}:{rappmgr_port}/rapps')
    print(f'Console command: curl -X GET http://{rappmgr_ip}:{rappmgr_port}/rapps')
    assert service_status.status_code == 200, f'Service status code: {service_status.status_code}'
    
    json_response = json.loads(service_status.text)
    assert type(json_response) is list, f'Response is not a list: {service_status.text}'
    print(f'Available rApps: {json_response}')

################################################################################
# Test the priming of a testing rApp
################################################################################
# def test_rapp_priming():
#     global rappmgr_ip, rappmgr_port, rapp_id, rapp_file_name
#     #remove_test_rapp_if_exists(rapp_id, rapp_file_name)

#     print("Priming testing rApp...")

#     prime_rapp = requests.put(f'http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id}', headers={'Content-Type': 'application/json'}, data=json.dumps(data))
#     print(f'Console command: curl -X PUT http://{rappmgr_ip}:{rappmgr_port}/rapps/{rapp_id} -H "Content-Type: application/json" -d \'{json.dumps(data)}\'')    
#     assert prime_rapp.status_code == 200, f'Priming rApp status code: {prime_rapp.status_code}'
