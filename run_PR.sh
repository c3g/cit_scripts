#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BRANCH=$1
COMMIT=$2

$SCRIPT_DIR/Jenkins_GenpipesFull.sh -b ${BRANCH} -c ${COMMIT}


