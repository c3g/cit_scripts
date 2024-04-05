#!/bin/bash

THIS_SCRIPT=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

function reject_command() {
    echo "Command rejected by $THIS_SCRIPT: $SSH_ORIGINAL_COMMAND"
    logger -t automation -p local0.info "Command rejected by $THIS_SCRIPT for user $USER: $SSH_ORIGINAL_COMMAND"

}

function pull_repo() {
    cd "$1" || return
    git checkout "$2"
    git pull
    echo "Pulled repo $1 on branch $2"
}

function disk_space_monitor() {
    pull_repo cit_scripts master
    bash Jenkins_diskSpaceMonitor.sh
}

function disk_space_monitor_mini() {
    pull_repo cit_scripts master
    bash Jenkins_diskSpaceMonitorMini.sh
}

function genpipes_full() {
    pull_repo cit_scripts master
    echo "running GenPipes Full on **** $HOSTNAME ****"
    args="${SSH_ORIGINAL_COMMAND#*GenPipes_Full }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "graham" ]]; then
        path="/project/6002326/C3G/projects/jenkins_tests"
    elif [[ $cluster == "cedar" ]]; then
        path="/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "narval" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "beluga" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    fi
    branch="$(echo "$args" | cut -d " " -f 2)"
    options="$(echo "$args" | cut -d " " -f 3)"
    cd "$(realpath "$path")" || return
    bash ./cleanup_old
    # shellcheck disable=SC2086
    $SCRIPT_DIR/integration_tests.sh -b ${branch} $options
}

function genpipes_update() {
    pull_repo cit_scripts master
    args="${SSH_ORIGINAL_COMMAND#*GenPipes_dev_update }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "graham" ]]; then
        path="/project/6002326/C3G/projects/jenkins_tests"
    elif [[ $cluster == "cedar" ]]; then
        path="/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "narval" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "beluga" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    fi
    branch="$(echo "$args" | cut -d " " -f 2)"
    latest=$(find "$path" -maxdepth 1 -type d -name "GenPipesFull_${branch}*" | sort | tail -n 1)
    options="$(echo "$args" | cut -d " " -f 3)"
    cd "${latest}/genpipes" || return
    git pull
    cd ../..
    # shellcheck disable=SC2086
    $SCRIPT_DIR/integration_tests.sh -d ${latest}/genpipes -u $options
}

function genpipes_command() {
    pull_repo cit_scripts master
    bash Jenkins_GenpipesCommands.sh
}

function update_cache() {
    args="${SSH_ORIGINAL_COMMAND#*cvmfs_cache_update }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "narval" ]]; then
        /project/def-bourqueg/LMOD_CACHE/update_cache.sh
    elif [[ $cluster == "beluga" ]]; then
        /lustre03/project/6002326/poq/lmod_caching/update_cache.sh
    fi
}

function moh_genpipes() {
    pull_repo moh_automation main
    bash jenkins_genpipes.sh "$(${SSH_ORIGINAL_COMMAND#*moh_genpipes } | tr -d '\"')"
}

function moh_wrapper() {
    pull_repo moh_automation main
    bash jenkins_wrapper.sh
}

logger -t automation -p local0.info "Command called by $THIS_SCRIPT for user $USER: $SSH_ORIGINAL_COMMAND"

case "$SSH_ORIGINAL_COMMAND" in
    Disk_Space_Monitor)
        disk_space_monitor
    ;;
    Disk_Space_Monitor_Mini)
        disk_space_monitor_mini
    ;;
    GenPipes_Full*)
        genpipes_full
    ;;
    GenPipes_dev_update*)
        genpipes_update
    ;;
    GenPipes_Command)
        genpipes_command
    ;;
    cvmfs_cache_update*)
        update_cache
    ;;
    MoH_GenPipes*)
        moh_genpipes
    ;;
    MoH_wrapper)
        moh_wrapper
    ;;
    *)
        reject_command
        ;;
esac
