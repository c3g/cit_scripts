#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BRANCH=$1
echo "running on **** $HOSTNAME ****"
if [[ $1 -eq cedar_full || graham_full  ]]; then
  $SCRIPT_DIR/integration_tests.sh -b dev -l

elif [ $# -eq beluga_full ]; then
  $SCRIPT_DIR/integration_tests.sh -b ${BRANCH} -l
fi
