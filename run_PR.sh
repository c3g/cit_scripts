#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BRANCH=$1
COMMIT=$2
echo "running on **** $HOSTNAME ****"
if [ $# -eq 1 ]; then
  $SCRIPT_DIR/Jenkins_GenpipesFull.sh -b ${BRANCH}

elif [ $# -eq 2 ]; then
  $SCRIPT_DIR/Jenkins_GenpipesFull.sh -b ${BRANCH} -c ${COMMIT}
fi
