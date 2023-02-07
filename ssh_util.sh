#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BRANCH=$1
host=$(hostname)
echo "running on **** $HOSTNAME ****"
ret_code=0
if [[ $2 == graham_full ]]; then
  cd $(realpath /project/6002326/C3G/projects/jenkins_tests)
  bash ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH} -l
  ret_code=$?
  scancel $USER
elif [[ $2 == graham_update ]]; then
  latest=$(ls -d $(realpath /project/6002326/C3G/projects/jenkins_tests/*${BRANCH}*) | sort | tail -n1)
  cd ${latest}/genpipes
  git pull
  cd ../..
  $SCRIPT_DIR/integration_tests.sh -u -d ${latest}/genpipes ${latest}/scriptTestOutputs
  ret_code=$?
  scancel $USER
elif [[ $2 == cedar_full ]]; then
  cd $(realpath /project/6007512/C3G/projects/jenkins_tests)
  bash ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH} -l
  ret_code=$?
  scancel $USER
elif [[ $2 == cedar_update ]]; then
  latest=$(ls -d $(realpath /project/6007512/C3G/projects/jenkins_tests/*${BRANCH}*) | sort | tail -n1)
  cd ${latest}/genpipes
  git pull
  cd ../..
  $SCRIPT_DIR/integration_tests.sh -u -d ${latest}/genpipes ${latest}/scriptTestOutputs
  ret_code=$?
  scancel $USER
elif [[ $2 == narval_full ]]; then
  # beluga FS mounted on narval 
  cd $(realpath /lustre03/project/6007512/C3G/projects/jenkins_tests)
  bash ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH}
  ret_code=$?
  scancel $USER
elif [[ $2 == narval_update ]]; then
  # beluga FS mounted on narval 
  latest=$(ls -d $(realpath /lustre03/project/6007512/C3G/projects/jenkins_tests/*${BRANCH}*) | sort | tail -n1)
  cd ${latest}/genpipes
  git pull
  cd ../..
  $SCRIPT_DIR/integration_tests.sh -u -d ${latest}/genpipes ${latest}/scriptTestOutputs
  ret_code=$?
  scancel $USER
elif [[ $2 == beluga_full ]]; then
  cd $(realpath /lustre03/project/6007512/C3G/projects/jenkins_tests)
  bash  ./cleanup_old
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH} 
  ret_code=$?
  scancel $USER
elif [[ $2 == beluga_update ]]; then
  latest=$(ls -d $(realpath /lustre03/project/6007512/C3G/projects/jenkins_tests/*${BRANCH}*) | sort | tail -n1)
  cd ${latest}/genpipes
  git pull
  cd ../..
  $SCRIPT_DIR/integration_tests.sh -u -v -d ${latest}/genpipes ${latest}/scriptTestOutputs
  ret_code=$?
  scancel $USER
fi
exit $ret_code
