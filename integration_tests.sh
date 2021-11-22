#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export SCRIPT_OUTPUT

## Server set up:

## guillaume's rrg account at CC's id is 6007512; the def account id is 6002326; change based on whether we have a RAC allocation on server or not

usage (){

echo
echo "usage: $0 creates the script for genpipes, submiting them on the HPC system"
echo
echo "   -p <pipeline1>[,pipeline2,...]       Pipeline to test, default: do them all"
echo "   -b <branch>                          Genpipe branch to test"
echo "   -c <commit>                          Hash string of the commit to test"
echo "   -s                                   Generate scritp only, no HPC submit"
echo "   -u                                   Update mode, do not remove latest pipeline run"
echo "   -l                                   Deploy genpipe in /tmp dir "
echo "   -d <genpipe repo_path>  <outputs path>"
echo "                                        Used preexisting genpipes repo as is (no update)"
echo "   -a                                   List all available pipeline and exit "
echo "   -w                                   Test with the container wrapper"
echo "   -f                                   Config file"
echo "   -h                                   Print this help "

}

function getopts-extra () {
    n=2 #number of needed options
    i=1
    # catch all non optional arguments following the flag
    while [[ ${OPTIND} -le $# && ${!OPTIND:0:1} != '-' ]]; do
        OPTARG[i]=${!OPTIND}
        let i++ OPTIND++
    done

    if [[ $n != $i ]]; then
      echo "wrong number of arguments ${i}, needed ${n}"
      usage
      exit 1
    fi
}

while getopts "hap:b:c:slud:wf:" opt; do
  case $opt in
    p)
      IFS=',' read -r -a PIPELINES <<< "${OPTARG}"
        export PIPELINES
      ;;
    d)
      getopts-extra "$@"
      export GENPIPES_DIR=$(realpath ${OPTARG[0]})
      export SCRIPT_OUTPUT=$(realpath ${OPTARG[1]}) # FEED TWO OPTIONS HERE!
      NO_GIT_CLONE=TRUE
      ;;
    b)
      BRANCH=${OPTARG}
      ;;
    c)
      COMMIT=${OPTARG}
      ;;
    f)
     CONFIG_FILE=${OPTARG}
      ;;
    l)
      export GENPIPES_DIR=$(mktemp -d /tmp/genpipes_XXXX)
      ;;
    s)
      export SCRIPT_ONLY=true
      ;;
    w)
      export CONTAINER_WRAPPER='--wrap'
      module load singularity > /dev/null 2>&1
      ;;
    a)
      export AVAIL=is_set
      echo available pipeline in the test suite
      ;;
    u)
      export UPDATE_MODE=true
      ;;
   h)
      usage
      exit 0
      ;;
   \?)
      usage
      exit 1
      ;;
  esac
done

def=6002326
rrg=6007512

HOST=`hostname`;
DNSDOMAIN=`dnsdomainname`;

export GENPIPES_CIT=
export server


export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6

if [[ $HOST == abacus* || $DNSDOMAIN == ferrier.genome.mcgill.ca ]]; then

  export TEST_DIR=/lb/project/mugqic/projects/jenkins_tests
  export serverName=Abacus
  export server=base
  export scheduler="pbs"

  read -r -d '' WRAP_CONFIG << EOM
export GEN_SHARED_CVMFS=/lb/project/mugqic/cvmfs-container
BIND_LIST=/tmp/,/home/,/lb
EOM

elif [[ $HOST == cedar* || $DNSDOMAIN == cedar.computecanada.ca ]]; then

  export TEST_DIR=/project/${rrg}/C3G/projects/jenkins_tests
  export serverName=cedar
  export server=cedar
  export scheduler="slurm"

  read -r -d '' WRAP_CONFIG << EOM
export GEN_SHARED_CVMFS=/scratch/$USER/cvmfs-container
BIND_LIST=/tmp/,/home/,/project,/scratch,/localscratch
EOM

elif [[ $HOST == gra-* || $DNSDOMAIN == graham.sharcnet ]]; then

  export TEST_DIR=/project/${def}/C3G/projects/jenkins_tests
  export serverName=graham
  export server=graham
  export scheduler="slurm"
  read -r -d '' WRAP_CONFIG << EOM
export GEN_SHARED_CVMFS=/scratch/$USER/cvmfs-container
BIND_LIST=/tmp/,/home/,/project,/scratch,/localscratch
EOM

elif [[ $HOST == beluga* || $DNSDOMAIN == beluga.computecanada.ca ]]; then
  export TEST_DIR=/project/${rrg}/C3G/projects/jenkins_tests
  export serverName=beluga
  export server=beluga
  export scheduler="slurm"
  read -r -d '' WRAP_CONFIG << EOM
export GEN_SHARED_CVMFS=/project/${rrg}/C3G/projects/jenkins_tests
BIND_LIST=/tmp/,/home/,/project,/scratch,/localscratch
EOM

else
  export TEST_DIR=/tmp/jenkins_tests
  export serverName=batch
  export server=beluga
  export scheduler="slurm"
  read -r -d '' WRAP_CONFIG << EOM
export GEN_SHARED_CVMFS=/home/$USER/cvmfs-cache
BIND_LIST=/tmp/,/home/
EOM

fi

if [ -n "${CONFIG_FILE}" ] ;then
  source ${CONFIG_FILE}
fi

## set up environment:

if [ -n "${BRANCH}" ] ;then
  branch=${BRANCH}
elif [ -z ${GENPIPES_BRANCH+x} ]; then
  branch=master
else
  branch=${GENPIPES_BRANCH}
fi

if [ -n "${COMMIT}" ] ;then
  commit=${COMMIT}
else
  commit=""
fi

if [[ -z ${GENPIPES_DIR} ]]; then
  if [ -n "${commit}" ] ; then
    GENPIPES_DIR=${TEST_DIR}/GenPipesFull_${branch}_${commit}
  else
    TIMESTAMP=`date +%FT%H.%M.%S`
    GENPIPES_DIR=${TEST_DIR}/GenPipesFull_${branch}_${TIMESTAMP}
  fi
fi

if [[ -z ${SCRIPT_OUTPUT} ]]; then
  SCRIPT_OUTPUT=${GENPIPES_DIR}/scriptTestOutputs
fi


## set up a dict to collect exit codes:
export RET_CODE_CREATE_SCRIPT
export RET_CODE_SUBMIT_SCRIPT
declare -A ExitCodes=()
export ExitCodes

## clone GenPipes from bitbucket

if [[ -z ${AVAIL+x} ]] ; then
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "Starting Genpipes Full Command tests today:  $(date)"
  echo "                                    Server:  ${serverName}"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

  mkdir -p ${GENPIPES_DIR}
  cd ${GENPIPES_DIR}

  if [ -z ${NO_GIT_CLONE+x} ]; then

    echo "cloning Genpipes ${branch} from: git@bitbucket.org:mugqic/genpipes.git"

    cd ${GENPIPES_DIR}
    echo cloning to ${GENPIPES_DIR}/genpipes
    if [ -d "genpipes" ]; then
      rm -rf genpipes
    fi
    git clone --depth 3 --branch ${branch} https://bitbucket.org/mugqic/genpipes.git
    if [ -n "${commit}" ]; then
      cd genpipes
      git checkout ${commit}
    fi

    export MUGQIC_PIPELINES_HOME=${GENPIPES_DIR}/genpipes
  else
    export MUGQIC_PIPELINES_HOME=${GENPIPES_DIR}
  fi

  if  [ -z ${CONTAINER_WRAPPER+x} ]; then
     echo 'using local cvmfs'
  elif [[ ${NO_GIT_CLONE} == TRUE ]]; then
    echo 'using preinstalled GiaC image'
  else
    get_wrapper=$(find ${GENPIPES_DIR} -type f -name get_wrapper.sh)
    echo yes | ${get_wrapper}
    container_path=$(dirname ${get_wrapper})
    echo "${WRAP_CONFIG}" > ${container_path}/etc/wrapper.conf
  fi

  ## set MUGQIC_PIPELINE_HOME to GenPipes bitbucket install:
  export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
fi

if [[ -z ${AVAIL+x} ]] ; then
  mkdir -p ${SCRIPT_OUTPUT}
  cd ${SCRIPT_OUTPUT}
fi

export pipeline
export technology
export run_pipeline
export PIPELINE_LONG_NAME
export PIPELINE_FOLDER
export PIPELINE_COMMAND

prologue () {
  # Folder is named pipeline_protocol
  PIPELINE_FOLDER=$1

  if [[ -z ${AVAIL+x} ]] ; then
    if [ -d "${PIPELINE_FOLDER}" ] && [[  -z ${UPDATE_MODE} ]] ; then
      rm -rf ${PIPELINE_FOLDER}
    fi
    mkdir -p ${PIPELINE_FOLDER}
  fi
}


generate_script () {
    local command=${1}
    extra="${@:2}"
    folder=${PIPELINE_FOLDER}
    PIPELINE_COMMAND=${command}

    module load mugqic/python/3.8.5 > /dev/null 2>&2
    echo "************************ running *********************************"
    echo "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py"\
    "-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini" \
    "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini" \
    "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini" \
    "${extra}" \
    "-o ${folder} ${CONTAINER_WRAPPER}" \
    "-j $scheduler --genpipes_file ${folder}/${command}"
    echo "******************************************************************"

    $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
    -c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
    $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
    $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
    ${extra} \
    -o ${folder} ${CONTAINER_WRAPPER} \
    -j $scheduler --genpipes_file ${folder}/${command}
    RET_CODE_CREATE_SCRIPT=$?
    ExitCodes+=(["${PIPELINE_LONG_NAME}_create"]="$RET_CODE_CREATE_SCRIPT")
    if [ "$RET_CODE_CREATE_SCRIPT" -ne 0 ] ; then
      echo ERROR on ${folder}/${command} creation
    fi
    module unload mugqic/python/3.8.5 > /dev/null 2>&2
}

submit () {
  command=${PIPELINE_FOLDER}/${PIPELINE_COMMAND}

  if [[ -z ${SCRIPT_ONLY} && ${RET_CODE_CREATE_SCRIPT} -eq 0 ]] ; then
      echo submiting $pipeline
      $MUGQIC_PIPELINES_HOME/utils/chunk_genpipes.sh  ${command} ${PIPELINE_FOLDER}/chunk
      # will retry submit 10 times
      $MUGQIC_PIPELINES_HOME/utils/monitor.sh -l 10 -n 999 ${PIPELINE_FOLDER}/chunk \
      | tee -a ${SCRIPT_OUTPUT}/all_jobs
      RET_CODE_SUBMIT_SCRIPT=${PIPESTATUS[0]}
      ExitCodes+=(["${PIPELINE_LONG_NAME}_submit"]="$RET_CODE_SUBMIT_SCRIPT")
      echo "${command} submit completed"
  else
      echo "${command} not submitted"
  fi
}

check_run () {
  # if there is not protocol remove the _
  PIPELINE_LONG_NAME=${1%%_}
  run_pipeline=false
  if [[ ! -z ${AVAIL+x} ]]; then
    echo - ${PIPELINE_LONG_NAME}
    return 0
  fi
  if [[ -z ${PIPELINES} ]]; then
    run_pipeline=true
  else
    if [[ " ${PIPELINES[@]} " =~ " ${PIPELINE_LONG_NAME} " ]]; then
      run_pipeline=true
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "                                     Now testing ${PIPELINE_LONG_NAME} "
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    fi
  fi
}

## chipseq.py:

pipeline=chipseq
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue ${pipeline}

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt

    submit

fi


pipeline=rnaseq
protocol=stringtie

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
    -t ${protocol}

    submit
fi


pipeline=rnaseq
protocol=cufflinks

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
    -t ${protocol}

      submit
fi


pipeline=dnaseq
protocol=mugqic

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} -l debug

    submit
fi

pipeline=dnaseq
protocol=mugqic
reference=gatk4
extra="$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/gatk4.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit_gatk4.ini"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"

    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} -l debug

    submit
fi

pipeline=dnaseq
protocol=mugqic
reference=b38
extra="$MUGQIC_PIPELINES_HOME/resources/genomes/config/Homo_sapiens.GRCh38.ini"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"

    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} -l debug

    submit

fi

pipeline=dnaseq
protocol=mugqic
reference=gatk4_b38
extra="$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/gatk4.ini $MUGQIC_PIPELINES_HOME/resources/genomes/config/Homo_sapiens.GRCh38.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit_gatk4.ini"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"

    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} -l debug

    submit

fi

pipeline=dnaseq
protocol=mpileup

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol}

    submit
fi

pipeline=dnaseq
protocol=mpileup
reference=b38
extra="$MUGQIC_PIPELINES_HOME/resources/genomes/config/Homo_sapiens.GRCh38.ini"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"

    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} -l debug

    submit

fi

#pipeline=dnaseq
#protocol=sv

#check_run "${pipeline}_${protocol}"
#if [[ ${run_pipeline} == 'true' ]] ; then
#    prologue "${pipeline}_${protocol}"


#    generate_script ${pipeline}_${protocol}_commands.sh \
#    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
#    -t ${protocol}

#    submit

#fi

pipeline=tumor_pair
protocol=fastpass
reference=b38
extra="$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.extras.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini $MUGQIC_PIPELINES_HOME/resources/genomes/config/Homo_sapiens.GRCh38.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini"
pair="$MUGQIC_INSTALL_HOME/testdata/${pipeline}/pair.${pipeline}.csv"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"


    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -p ${pair} \
    -t ${protocol}

    submit

fi

pipeline=tumor_pair
protocol=ensemble
reference=b38
extra="$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.extras.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini $MUGQIC_PIPELINES_HOME/resources/genomes/config/Homo_sapiens.GRCh38.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini"
pair="$MUGQIC_INSTALL_HOME/testdata/${pipeline}/pair.${pipeline}.csv"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"


    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -p ${pair} \
    -t ${protocol}

    submit

fi

pipeline=tumor_pair
protocol=ensemble
reference=exome_b38
extra="$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.extras.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.exome.ini $MUGQIC_PIPELINES_HOME/resources/genomes/config/Homo_sapiens.GRCh38.ini $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini"
pair="$MUGQIC_INSTALL_HOME/testdata/${pipeline}/pair.${pipeline}.csv"

check_run "${pipeline}_${protocol}_${reference}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}_${reference}"


    generate_script ${pipeline}_${protocol}_${reference}_commands.sh \
    ${extra} \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.exome.b38.txt \
    -p ${pair} \
    -t ${protocol}

    submit

fi

pipeline=dnaseq_high_coverage
technology=dnaseq
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt

    submit
fi


pipeline=hicseq
protocol=hic
extra="-e MboI"

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}_${protocol}.txt \
    -t ${protocol} ${extra}

    submit
fi


pipeline=hicseq
protocol=capture
extra="-e MboI"

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    ## soft link to capture bed file
    ln -s $MUGQIC_INSTALL_HOME/testdata/hicseq/GSE69600_promoter_capture_bait_coordinates.bed \
    ${pipeline}_${protocol}/GSE69600_promoter_capture_bait_coordinates.bed

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} ${extra}

    submit
fi


pipeline=rnaseq_light
protocol=''
technology=rnaseq

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${technology}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${technology}.txt

    submit
fi


pipeline=rnaseq_denovo_assembly
technology=rnaseq
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${technology}/design.${technology}.txt

    submit
fi


pipeline=methylseq
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt

    submit
fi


pipeline=ampliconseq
protocol=dada2

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then

    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
    -t ${protocol}

    submit
fi


pipeline=ampliconseq
protocol=qiime

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol}

    submit
fi


pipeline=nanopore
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt

    submit
fi


pipeline=covseq
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt

    submit
fi


pipeline=epiqc
protocol=''


check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \

    submit
fi


if [[ ! -z ${AVAIL+x} ]] ; then
   exit 0
fi


# Add new test above ^^


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Testing GenPipes Command Complete ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# Warning for ini files with dev configuration
WARNING=$(find $GENPIPES_DIR  -type f -name "*ini" | xargs grep "mugqic_dev\|HOME_DEV")
if [[ $? ==  0 ]] ; then
  printf 'WARNING, Genpipes in not production ready, it still has reference to DEV software and references in ini files: \n%s\n' "$WARNING" | sed 's|^[^W]|\t|'
fi


# Print result of script creation and submit
ret_code=0
to_sort=""
for key in "${!ExitCodes[@]}"; do
  to_sort+="$key return  ${ExitCodes[$key]}
"
  if [[ ${ExitCodes[$key]} != 0 ]]; then
    ret_code=${ExitCodes[$key]}
  fi
done

echo "$to_sort" | sort

# that  should be an option, not a hidden condition
if [[ $server == beluga && $USER == c3g_cit ]]  ; then
  ${SCRIPT_DIR}/run_after.sh
fi

exit $ret_code
