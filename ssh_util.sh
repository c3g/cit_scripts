#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BRANCH=$1
echo "running on **** $HOSTNAME ****"
ret_code=0
if [[ $1 -eq graham_full  ]]; then
  cd /project/6002326/C3G/projects/jenkins_tests
  bash ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b dev -l
  ret_code=$?
  scancel $USER
elif [[ $1 -eq cedar_full  ]]; then
  cd /project/6007512/C3G/projects/jenkins_tests
  bash ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b dev -l
  ret_code=$?
  scancel $USER
elif [ $# -eq beluga_full ]; then
  cd /lustre03/project/6007512/C3G/projects/jenkins_tests
  bash  ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH} -l
  ret_code=$?
fi
exit $ret_code
