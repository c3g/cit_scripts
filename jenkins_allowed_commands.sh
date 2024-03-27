#!/bin/bash

THIS_SCRIPT=$(basename "$0")

function reject_command() {
    echo "Command rejected by $THIS_SCRIPT: $SSH_ORIGINAL_COMMAND"
    logger -t automation -p local0.info "Command rejected by $THIS_SCRIPT for user $USER: $SSH_ORIGINAL_COMMAND"

}

function disk_space_monitor() {
    bash Jenkins_diskSpaceMonitor.sh
}

function disk_space_monitor_mini() {
    cd cit_scripts && git checkout master && git pull && bash Jenkins_diskSpaceMonitorMini.sh
}

function genpipes_full() {
    cd cit_scripts && git checkout master && git pull && bash ssh_util.sh "$(${SSH_ORIGINAL_COMMAND#*genpipes_full })"
}

function genpipes_command() {
    cd cit_scripts && git checkout master && git pull && bash Jenkins_GenpipesCommands.sh
}

function update_cache() {
    /lustre03/project/6002326/poq/lmod_caching/update_cache.sh
}

function moh_genpipes() {
    cd moh_automation && git checkout main && git pull && bash jenkins_genpipes.sh "$(${SSH_ORIGINAL_COMMAND#*moh_genpipes } | tr -d '\"')"
}

function moh_wrapper() {
    cd moh_automation && git checkout main && git pull && bash jenkins_wrapper.sh
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
    GenPipes_Command)
        genpipes_command
    ;;
    cvmfs_cache_update)
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
