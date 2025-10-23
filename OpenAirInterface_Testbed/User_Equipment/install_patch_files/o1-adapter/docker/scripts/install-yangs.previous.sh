#!/bin/bash

# /*
# * Licensed to the OpenAirInterface (OAI) Software Alliance under one or more
# * contributor license agreements.  See the NOTICE file distributed with
# * this work for additional information regarding copyright ownership.
# * The OpenAirInterface Software Alliance licenses this file to You under
# * the OAI Public License, Version 1.1  (the "License"); you may not use this file
# * except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *      http://www.openairinterface.org/?page_id=698
# *
# * Copyright: Fraunhofer Heinrich Hertz Institute
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# *-------------------------------------------------------------------------------
# * For more information about the OpenAirInterface (OAI) Software Alliance:
# *      contact@openairinterface.org
# */


DIRBIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DIR_YANGS="$DIRBIN/yang"

declare yang_files=(
    "ietf-inet-types.yang"
    "ietf-yang-schema-mount@2019-01-14.yang"
    "ietf-yang-types@2013-07-15.yang"

    "_3gpp-common-yang-extensions.yang"
    "_3gpp-common-yang-types.yang"
    "_3gpp-common-top.yang"
    "_3gpp-common-files.yang"
    "_3gpp-common-measurements.yang"
    "_3gpp-common-ep-rp.yang"
    "_3gpp-common-subscription-control.yang"
    "_3gpp-common-fm.yang"
    "_3gpp-common-trace.yang"
    "_3gpp-5gc-nrm-configurable5qiset.yang"
    "_3gpp-5gc-nrm-ecmconnectioninfo.yang"
    "_3gpp-common-subnetwork.yang"
    "_3gpp-common-managed-element.yang"
    "_3gpp-5g-common-yang-types.yang"
    "_3gpp-common-managed-function.yang"
    "_3gpp-common-managementdatacollection.yang"
    "_3gpp-common-mnsregistry.yang"
    "_3gpp-common-qmcjob.yang"
    "_3gpp-nr-nrm-gnbdufunction.yang"
    "_3gpp-nr-nrm-gnbcucpfunction.yang"
    "_3gpp-nr-nrm-gnbcuupfunction.yang"
    "_3gpp-nr-nrm-bwp.yang"
    "_3gpp-nr-nrm-nrcelldu.yang"
    "_3gpp-nr-nrm-nrsectorcarrier.yang"
    "_3gpp-common-filemanagement.yang"
    "_3gpp-nr-nrm-ep.yang"
)

# checkAL ERROR IN 3GPP FILES
sed -i 's/length 6/length 8/g' $DIRBIN/yang/_3gpp-5g-common-yang-types.yang

for file in "${yang_files[@]}"
do
    echo "$DIR_YANGS/$file"
    sysrepoctl -i "$DIR_YANGS/$file" -s "$DIR_YANGS"
done

sysrepoctl -c _3gpp-common-managed-function -e MeasurementsUnderManagedFunction
sysrepoctl -c _3gpp-common-managed-element -e FmUnderManagedElement
