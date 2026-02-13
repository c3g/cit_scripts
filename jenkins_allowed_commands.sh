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
    pull_repo cit_scripts main
    bash Jenkins_diskSpaceMonitor.sh
}

function disk_space_monitor_mini() {
    pull_repo cit_scripts main
    bash Jenkins_diskSpaceMonitorMini.sh
}

function genpipes_full() {
    pull_repo cit_scripts main
    echo "running GenPipes Full on **** $HOSTNAME ****"
    args="${SSH_ORIGINAL_COMMAND#*GenPipes_Full }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "graham" ]]; then
        path="/project/6002326/C3G/projects/jenkins_tests"
    elif [[ $cluster == "fir" ]]; then
        path="/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "narval" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "beluga" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "rorqual" ]]; then
        path="/project/rrg-bourqueg-ad/C3G/projects/jenkins_tests"
    fi
    branch="$(echo "$args" | cut -d " " -f 2)"
    options="$(echo "$args" | cut -d " " -f 3)"
    cd "$(realpath "$path")" || return
    bash ./cleanup_old
    # shellcheck disable=SC2086
    $SCRIPT_DIR/integration_tests.sh -b ${branch} $options
}

function genpipes_update() {
    pull_repo cit_scripts main
    args="${SSH_ORIGINAL_COMMAND#*GenPipes_dev_update }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "graham" ]]; then
        path="/project/6002326/C3G/projects/jenkins_tests"
    elif [[ $cluster == "fir" ]]; then
        path="/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "narval" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "beluga" ]]; then
        path="/lustre03/project/6007512/C3G/projects/jenkins_tests"
    elif [[ $cluster == "rorqual" ]]; then
        path="/project/rrg-bourqueg-ad/C3G/projects/jenkins_tests"
    fi
    branch="$(echo "$args" | cut -d " " -f 2)"
    latest=$(find "$path" -maxdepth 1 -type d -name "GenPipesFull_${branch}*" | sort | tail -n 1)
    options="$(echo "$args" | cut -d " " -f 3)"
    cd "${latest}/genpipes" || return
    git pull
    cd ../..
    # shellcheck disable=SC2086
    $SCRIPT_DIR/integration_tests.sh -d ${latest}/genpipes ${latest}/scriptTestOutputs -u $options
}

function genpipes_command() {
    pull_repo cit_scripts main
    bash Jenkins_GenpipesCommands.sh
}

function update_cache() {
    args="${SSH_ORIGINAL_COMMAND#*cvmfs_cache_update }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "narval" ]]; then
        /project/def-bourqueg/LMOD_CACHE/update_cache.sh
    elif [[ $cluster == "rorqual" ]]; then
        /project/def-bourqueg/LMOD_CACHE/update_cache.sh
    fi
}

function moh_genpipes() {
    pull_repo moh_automation main
    bash jenkins_genpipes.sh "$(${SSH_ORIGINAL_COMMAND#*MoH_GenPipes } | tr -d '\"')"
}

function moh_wrapper() {
    pull_repo moh_automation main
    bash jenkins_wrapper.sh
}

function check_genpipes() {
    pull_repo moh_automation main
    timestamp=$(date "+%Y-%m-%dT%H.%M.%S")
    args="${SSH_ORIGINAL_COMMAND#*MoH_check_GenPipes }"
    cluster="$(echo "$args" | cut -d " " -f 1)"
    if [[ $cluster == "abacus" ]]; then
        path="/lb/project/mugqic/projects/MOH/MAIN"
    elif [[ $cluster == "beluga" ]]; then
        path="/lustre03/project/6007512/C3G/projects/MOH_PROCESSING/MAIN"
    elif [[ $cluster == "cardinal" ]]; then
        path="/project/def-c3g/MOH/MAIN"
    elif [[ $cluster == "rorqual" ]]; then
        path="/project/6007512/shared/C3G/projects/MOH_PROCESSING/MAIN"
    elif [[ $cluster == "narval" ]]; then
        path="/lustre06/project/6084703/C3G/projects/MOH/MAIN"
    elif [[ $cluster == "fir" ]]; then
        path="/project/6007512/C3G/projects/MOH/MAIN"
    fi
    logs_folder="$path/check_genpipes_logs/$timestamp"
    mkdir -p "$logs_folder"
    log_file="$logs_folder/check_genpipes_$timestamp.log"
    cat /dev/null > "$log_file"
    folder_to_be_checked=$(find "$path/genpipes_submission" -mindepth 1 -maxdepth 1 -type d '!' -exec test -e "{}.checked" ';' -print)
    for folder in $folder_to_be_checked; do
        json=$(find "$folder" -lname "*.json")
        job_list=$(find "$folder" -lname "*job_list*")
        readset=$(find "$folder" -lname "*readset.tsv")
        missing_files=""
        if [[ -z $json ]]; then
            missing_files+="json "
        fi

        if [[ -z $readset ]]; then
            missing_files+="readset "
        fi

        if [[ -z $job_list ]]; then
            missing_files+="job_list "
        fi
        if [[ -n $missing_files ]]; then
            echo "WARNING: Missing files ($missing_files) in $folder. Skipping..." 2>&1 | tee -a "$log_file"
        else
            # shellcheck disable=SC2086
            bash check_GenPipes.sh -c $cluster -j $json -r $readset -l $job_list 2>&1 | tee -a "$log_file"
        fi
    done
    # shellcheck disable=SC2086
    bash parse_check_GenPipes_log.sh -l $log_file -o $logs_folder
    transfers=$(grep "Transferring GenPipes run" "$log_file" | awk -F'run ' '{print $2}' | sed 's/\.\.\.//g')
    if [[ -n $transfers ]]; then
        echo "$transfers" > "$logs_folder/check_genpipes_$timestamp.transfers"
    fi
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
    MoH_check_GenPipes*)
        check_genpipes
    ;;
    *)
        reject_command
        ;;
esac
