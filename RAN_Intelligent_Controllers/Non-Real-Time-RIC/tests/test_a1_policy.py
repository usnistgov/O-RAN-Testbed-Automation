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
import pytest
import requests

config.load_kube_config()
v1 = client.CoreV1Api()

# A1 Policy API: https://docs.onap.org/projects/onap-ccsdk-oran/en/latest/offeredapis/offeredapis.html#offered-apis

################################################################################
# Test that the Policy Management Service pod is running
################################################################################
def test_pod_status():
    global pms_pod_name, pms_ip, pms_port
    pms_pod_name = v1.list_namespaced_pod('nonrtric', label_selector='app=nonrtric-policymanagementservice').items[0].metadata.name
    pms_ip = v1.read_namespaced_pod(pms_pod_name, 'nonrtric').status.pod_ip
    pms_port=8081
    
    assert pms_pod_name is not None, 'Policy Management Service pod not found'
    assert pms_ip is not None, 'Policy Management Service IP not found'
    assert pms_port is not None, 'Policy Management Service port not found'
    
    print(f'IP of {pms_pod_name}: {pms_ip}')
    print(f'Port of {pms_pod_name}: {pms_port}')

################################################################################
# Test that the Policy Management Service status is success
################################################################################
def test_policymanagementservice_status():
    global pms_ip, pms_port
    service_status = requests.get(f'http://{pms_ip}:{pms_port}/a1-policy/v2/status')
    print(f'Console command: curl -X GET http://{pms_ip}:{pms_port}/a1-policy/v2/status')
    assert service_status.status_code == 200, f'Service status code: {service_status.status_code}'
    
    json_response = json.loads(service_status.text)

    assert 'status' in json_response, f'Response doesn\'t contain "status": {service_status.text}'
    assert json_response['status'] == 'success', f'Service status: {json_response["status"]}'

################################################################################ 
# Test the retrieval of the RICs list
################################################################################
def test_rics_list():
    global pms_ip, pms_port, ric_ids, ric_policy_ids
    rics_list = requests.get(f'http://{pms_ip}:{pms_port}/a1-policy/v2/rics')   
     
    assert rics_list.status_code == 200, f'Rics list status code: {rics_list.status_code}'
    
    json_response = json.loads(rics_list.text)
    
    assert 'rics' in json_response, 'Rics key not found'
    assert len(json_response['rics']) > 0, 'No ric found'
    
    ric_ids = []
    for ric in json_response['rics']:
        ric_ids.append(ric['ric_id'])
        
    print(f'Available RIC IDs: {ric_ids}')
    
    ric_policy_ids = []
    for ric in json_response['rics']:
        ric_id = ric['ric_id']
        print("Testing RIC: ", ric_id)
        policy_ids_response = requests.get(f'http://{pms_ip}:{pms_port}/a1-policy/v2/rics/ric?ric_id={ric["ric_id"]}')
        print(f'Console command: curl -X GET http://{pms_ip}:{pms_port}/a1-policy/v2/rics/ric?ric_id={ric["ric_id"]}')
        assert policy_ids_response.status_code == 200, f'Ric data status code: {policy_ids_response.status_code}'
        print(f'    {policy_ids_response.text}')
        
        json_response = json.loads(policy_ids_response.text)
        ric_policy_ids.append([ric_id, json_response['policytype_ids']])

# Delete a policy if it exists
def delete_policy_if_exists(policy_id):
    global pms_ip, pms_port
    policy_exists = requests.get(f'http://{pms_ip}:{pms_port}/a1-policy/v2/policies/{policy_id}')
    if policy_exists.status_code == 200:
        print(f'Policy {policy_id} exists, deleting it...')
        delete_policy = requests.delete(f'http://{pms_ip}:{pms_port}/a1-policy/v2/policies/{policy_id}')
        print(f'Console command: curl -X DELETE http://{pms_ip}:{pms_port}/a1-policy/v2/policies/{policy_id}')
        assert delete_policy.status_code == 200, f'Delete policy status code: {delete_policy.status_code}'

################################################################################
# Test the creation of a policy
################################################################################
def test_create_policy():
    global pms_ip, pms_port, ric_ids, ric_policy_ids, supported_policy_types, supported_policy_types_ric, policy_id, service_id
    supported_policy_types = []
    supported_policy_types_ric = []
    for ric in ric_policy_ids:
        ric_id = ric[0]
        policy_types = ric[1]
        if len(policy_types) > 0:
            for policy_type in policy_types:
                if policy_type is not None:
                    supported_policy_types.append(policy_type)
                    supported_policy_types_ric.append(ric_id)
    
    assert len(supported_policy_types) > 0, 'No supported policy types found'
    print(f'Supported policy types: {supported_policy_types}')
    
    policy_id=123456
    service_id=654321
    policy_data = {
        'ric_id': supported_policy_types_ric[0],
        'policy_id': policy_id,
        'transient': False,
        'service_id': service_id,
        'policy_data': {},
        'status_notification_uri': '',
        'policytype_id': supported_policy_types[0]
    }
    
    delete_policy_if_exists(policy_id)

    create_policy = requests.put(f'http://{pms_ip}:{pms_port}/a1-policy/v2/policies', headers={'Content-Type': 'application/json'}, data=json.dumps(policy_data))
    print(f'Console command: curl -X PUT http://{pms_ip}:{pms_port}/a1-policy/v2/policies -H "Content-Type: application/json" -d \'{json.dumps(policy_data)}\'')

    assert create_policy.status_code == 200 or create_policy.status_code == 201, f'Create policy status code: {create_policy.status_code}'

################################################################################
# Test the retrieval of the created policy
################################################################################
def test_get_policy():
    global pms_ip, pms_port, policy_id, service_id
    get_policy = requests.get(f'http://{pms_ip}:{pms_port}/a1-policy/v2/policies?service_id={service_id}')
    print(f'Console command: curl -X GET http://{pms_ip}:{pms_port}/a1-policy/v2/policies?service_id={service_id}')
    
    assert get_policy.status_code == 200, f'Get policy status code: {get_policy.status_code}'
    
    json_response = json.loads(get_policy.text)
    assert 'policy_ids' in json_response, 'Policy IDs key not found'
    assert str(policy_id) in json_response['policy_ids'], 'Policy ID not found'

################################################################################
# Test the deletion of the created policy
################################################################################
def test_delete_policy():
    global pms_ip, pms_port, policy_id
    delete_policy = requests.delete(f'http://{pms_ip}:{pms_port}/a1-policy/v2/policies/{policy_id}')
    print(f'Console command: curl -X DELETE http://{pms_ip}:{pms_port}/a1-policy/v2/policies/{policy_id}')
    
    assert delete_policy.status_code == 200 or delete_policy.status_code == 204, f'Delete policy status code: {delete_policy.status_code}'
