#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BRANCH=$1
echo "running on **** $HOSTNAME ****"
if [[ $1 -eq graham_full  ]]; then
  $SCRIPT_DIR/integration_tests.sh -b dev -l
  cd /project/6002326/C3G/projects/jenkins_tests
  bash ./cleanup_old

elif [[ $1 -eq cedar_full  ]]; then
  $SCRIPT_DIR/integration_tests.sh -b dev -l
  cd /project/6007512/C3G/projects/jenkins_tests
  bash ./cleanup_old

elif [ $# -eq beluga_full ]; then
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH} -l
  cd /lustre03/project/6007512/C3G/projects/jenkins_tests
  bash  ./cleanup_old
fi
