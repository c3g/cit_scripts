#!/usr/bin/env bash

## Server set up:

## guillaume's rrg account at CC's id is 6007512; the def account id is 6002326; change based on whether we have a RAC allocation on server or not

usage (){

echo
echo "usage: $0 create the script for genpipes, submiting them on the HPC system"
echo
echo "   -p <pipeline1>[,pipeline2,...]       Pipeline to test, default: do them all"
echo "   -b <branch>                          Genpipe branch to test"
echo "   -c <commit>                          Hash string of the commit to test"
echo "   -s                                   generate scritp only, no HPC submit"
echo "   -u                                   update mode, do not remove latest pipeline run"
echo "   -l                                   deploy genpipe in /tmp dir "
echo "   -a                                   list all available pipeline and exit "
echo "   -h                                   print this help "

}


while getopts "hap:b:c:slu" opt; do
  case $opt in
    p)
      IFS=',' read -r -a PIPELINES <<< "${OPTARG}"
        export PIPELINES
      ;;
    b)
      BRANCH=${OPTARG}
      ;;
    c)
      COMMIT=${OPTARG}
      ;;
    l)
      export GENPIPES_DIR=$(mktemp -d /tmp/genpipes_XXXX)
      ;;
    s)
      export SCRIPT_ONLY=true
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

elif [[ $HOST == lg-* || $DNSDOMAIN == guillimin.clumeq.ca ]]; then

  export TEST_DIR=/genfs/C3G/projects/jenkins_tests
  export serverName=guillimin
  export server=guillimin
  export scheduler="pbs"

elif [[ $HOST == ip* ]]; then

  export TEST_DIR=/project/${rrg}/C3G/projects/jenkins_tests
  export serverName=mp2b
  export server=mp2b
  export scheduler="slurm"

elif [[ $HOST == cedar* || $DNSDOMAIN == cedar.computecanada.ca ]]; then

  export TEST_DIR=/project/${rrg}/C3G/projects/jenkins_tests
  export serverName=cedar
  export server=cedar
  export scheduler="slurm"

elif [[ $HOST == gra-* || $DNSDOMAIN == graham.sharcnet ]]; then

  export TEST_DIR=/project/${def}/C3G/projects/jenkins_tests
  export serverName=graham
  export server=graham
  export scheduler="slurm"

elif [[ $HOST == beluga* || $DNSDOMAIN == beluga.computecanada.ca ]]; then
  export TEST_DIR=/project/${rrg}/C3G/projects/jenkins_tests
  export serverName=beluga
  export server=beluga
  export scheduler="slurm"

else
  export TEST_DIR=/tmp/jenkins_tests
  export serverName=batch
  export server=beluga
  export scheduler="slurm"

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

  echo "cloning Genpipes ${branch} from: git@bitbucket.org:mugqic/genpipes.git"

  if [ -d "genpipes" ]; then
    rm -rf genpipes
  fi

  cd ${GENPIPES_DIR}
  echo cloning to ${GENPIPES_DIR}/genpipes
  git clone --depth 3 --branch ${branch} git@bitbucket.org:mugqic/genpipes.git
  if [ -n "${commit}" ]; then
    cd genpipes
    git checkout ${commit}
  fi

  ## set MUGQIC_PIPELINE_HOME to GenPipes bitbucket install:
  export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
  export MUGQIC_PIPELINES_HOME=${GENPIPES_DIR}/genpipes
fi

if [[ -z ${AVAIL+x} ]] ; then
  mkdir -p ${GENPIPES_DIR}/scriptTestOutputs
  cd ${GENPIPES_DIR}/scriptTestOutputs
fi

export pipeline
export technology
export run_pipeline
export protocol
export protocol
export PIPELINE_FOLDER
export PIPELINE_COMMAND

prologue () {
  # Folder is named pipeline_protocole
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

  module load mugqic/python/2.7.14
  echo "************************ running *********************************"
  echo "python $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py"\
  "-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini" \
  "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini" \
  "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini" \
  "${extra}" \
  "-o ${folder}" \
  "-j $scheduler > ${folder}/${command}"
  echo "******************************************************************"

  python $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
  -c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
  $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
  $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
  ${extra} \
  -o ${folder} \
  -j $scheduler > ${folder}/${command}
  RET_CODE_CREATE_SCRIPT=$?
  ExitCodes+=(["${pipeline}_${protocol}_create"]="$RET_CODE_CREATE_SCRIPT")
  if [ "$RET_CODE_CREATE_SCRIPT" -ne 0 ] ; then
    echo ERROR on ${folder}/${command} creation
  fi
}

submit () {
  command=${PIPELINE_FOLDER}/${PIPELINE_COMMAND}

  if [[ -z ${SCRIPT_ONLY} && ${RET_CODE_CREATE_SCRIPT} -eq 0 ]] ; then
      module purge
      echo submiting $pipeline
      bash ${command}
      RET_CODE_SUBMIT_SCRIPT=$?
      ExitCodes+=(["${pipeline}_${protocol}_submit"]="$RET_CODE_SUBMIT_SCRIPT")
      echo "${command} submit completed"
  else
      echo "${command} not submitted"
  fi
}

check_run () {
  # if there is not protocol remove the _
  pip=${1%%_}
  run_pipeline=false
  if [[ ! -z ${AVAIL+x} ]]; then
    echo - ${pip}
    return 0
  fi
  if [[ -z ${PIPELINES} ]]; then
    run_pipeline=true
  else
    if [[ " ${PIPELINES[@]} " =~ " ${pip} " ]]; then
      run_pipeline=true
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "                                     Now testing ${pip} "
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
protocol=mpileup

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
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

    submit ${pipeline}/${pipeline}_commands.sh
fi


pipeline=covseq
protocol=''

check_run "${pipeline}_${protocol}"
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r ${pipeline}/readset.${pipeline}.txt

    submit
fi


if [[ ! -z ${AVAIL+x} ]] ; then
   exit 0
fi


# Add new test above ^^


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Testing GenPipes Command Complete ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
ret_code=0
for key in "${!ExitCodes[@]}"; do
  echo $key return  ${ExitCodes[$key]}
  if [[ ${ExitCodes[$key]} != 0 ]]; then
    ret_code=${ExitCodes[$key]}
  fi
done
exit $ret_code
