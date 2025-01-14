#!/bin/bash

#  ============LICENSE_START===============================================
#  Copyright (C) 2023 Nordix Foundation. All rights reserved.
#  Copyright (C) 2024 OpenInfra Foundation Europe. All rights reserved.
#  ========================================================================
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  ============LICENSE_END=================================================
#

if [[ $# -ne 1 ]]; then
  echo "USAGE: $0 <rApp-resource-folder-name>"
  exit 1
fi

if ! command -v zip &> /dev/null; then
  echo "Zip command not found. Please install zip to proceed."
  exit 1
fi

if ! command -v helm &> /dev/null; then
  echo "Helm command not found. Please install helm to proceed."
  exit 1
fi

DIRECTORY=${1%/}
PACKAGENAME="$DIRECTORY.csar"
HELM_DIR="$DIRECTORY/Artifacts/Deployment/HELM"
EXCLUDE_DIRS=()

checkHelmPackage() {
  if [ -d "$HELM_DIR" ]; then
    for dir in "$HELM_DIR"/*/ ; do
      if [ -d "$dir" ]; then
        HELM_PACKAGE_NAME=$(basename "$dir")
        pushd "$HELM_DIR"
        helm package "$HELM_PACKAGE_NAME"
        popd
        EXCLUDE_DIRS+=("*/$HELM_PACKAGE_NAME/*")
      fi
    done
  else
    echo "Helm directory $HELM_DIR doesn't exist."
  fi
}

if [ -d "$DIRECTORY" ]; then
  checkHelmPackage
  rm -f $PACKAGENAME 2> /dev/null
  pushd $DIRECTORY
  zip -r ../$PACKAGENAME * $(printf " -x %s" "${EXCLUDE_DIRS[@]}")
  popd
  echo -e "rApp package $PACKAGENAME generated."
else
  echo "Directory $DIRECTORY doesn't exist."
fi
