#!/usr/bin/env bash

## Server set up:


## guillaume's rrg account at CC's id is 6007512; the def account id is 6002326; change based on whether we have a RAC allocation on server or not

usage (){

echo
echo "usage: $0 create the script for genpipes, submiting them on the HPC system"
echo
echo "   -p <pipeline1>[,pipeline2,...]       Pipeline to test, default: do them all"
echo "   -b <branch>                          Genpipe branch to test"
echo "   -s                                   generate scritp only, no HPC submit"
echo "   -d  <path to genpipes repo>          run in debug mode"
echo "   -u                                   update mode, do not remove latest pipeline run"
echo "   -l                                   deploy genpipe in /tmp dir "

}


while getopts "p:b:sld:u" opt; do
  case $opt in
    p)
      IFS=',' read -r -a PIPELINES <<< "${OPTARG}"
        export PIPELINES
      ;;
    b)
      BRANCH=${OPTARG}
      ;;
    l)
      GENPIPES_DIR=$(mktemp -d /tmp/genpipes_XXXX)
      ;;
    s)
      SCRIPT_ONLY=true
      ;;
    u)
      export UPDATE_MODE=true
      ;;
    d)
      export DEBUG=true
      MUGQIC_PIPELINES_HOME=${OPTARG}
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
  export server=cedar
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


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Starting Genpipes Full Command tests today:  $(date)"
echo "                                    Server:  ${serverName}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## set up environment:

if [[ -z  ${GENPIPES_DIR} ]]; then
  ${GENPIPES_DIR} = ${TEST_DIR}/GenPipesFull
fi

module load mugqic/python/2.7.14

## set up a dict to collect exit codes:
declare -A ExitCodes=()

if [[ -z ${DEBUG} ]] ; then
  mkdir -p ${TEST_DIR}/GenPipesFull
  cd ${TEST_DIR}/GenPipesFull
fi
## clone GenPipes from bitbucket

if [ -n "${BRANCH}" ] ;then
  branch=${BRANCH}
elif [ -z ${GENPIPES_BRANCH+x} ]; then
 branch=master
else
 branch=${GENPIPES_BRANCH}
fi

echo "cloning Genpipes ${branch} from: git@bitbucket.org:mugqic/genpipes.git"

if [ -d "genpipes" ]; then
  rm -rf genpipes
fi

if [[ -z ${DEBUG} ]] ; then
  cd ${GENPIPES_DIR}
  git clone --depth 1 --branch ${branch} git@bitbucket.org:mugqic/genpipes.git

  ## set MUGQIC_PIPELINE_HOME to GenPipes bitbucket install:
  export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
  export MUGQIC_PIPELINES_HOME=${GENPIPES_DIR}/genpipes
fi


if [[ -z ${DEBUG} ]] ; then
  mkdir -p ${TEST_DIR}/GenPipesFull/scriptTestOutputs
  cd ${TEST_DIR}/GenPipesFull/scriptTestOutputs
fi

pipelines=(chipseq dnaseq rnaseq hicseq methylseq pacbio_assembly ampliconseq  dnaseq_high_coverage
rnaseq_denovo_assembly rnaseq_light tumor_pair illumina_run_processing)

export pipeline
export steps
export technology
export run_pipeline

prologue () {

  folder=$1
  if [[ -z ${DEBUG} ]] ; then
    if [ -d "${folder}" ] && [[  -z ${UPDATE_MODE} ]] ; then
      rm -rf ${folder}
    fi
    mkdir -p ${folder}
    cd ${folder}
  fi
}

generate_script () {
  local commands=${1}
  extra="${@:1}"

  module load mugqic/python/2.7.14
  echo "************************ running *********************************"
  echo "python $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py"\
  "-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini" \
  "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini" \
  "$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini" \
  "${extra}" \
  "-j $scheduler > ${commands}"
  echo "******************************************************************"

  python $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
  -c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
  $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
  $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
  ${extra} \
  -j $scheduler > ${commands}

}

submit () {
  command=${1}
  echo $pipeline

  if [[ -z "${SCRIPT_ONLY}" ]] || [[ -z ${DEBUG} ]] ; then
    module purge
      bash ${command}
      echo "${command} submit completed"
    else
      echo "${command} not submitted"
  fi
}


check_run () {
  run_pipeline=false

  if [[ -z ${PIPELINES} ]]; then
    run_pipeline=true
  else
    for p in ${PIPELINES} ; do
      if [[ ${p}  == ${pipeline} ]]; then
        run_pipeline=true
      fi
    done
  fi
}

## chipseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing ChIPSeq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

pipeline=chipseq
steps=19

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue ${pipeline}
    # generate_script ${pipeline} ${steps} -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt -d \
    # $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt


    ExitCodes+=(["${pipeline}"]="$?")

    if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
    #   module purge
    #   bash ${pipeline}_commands.sh
    #   echo "${pipeline} jobs submitted"
      submit ${pipeline}_commands.sh

    fi

    cd ../
fi
## rnaseq.py -t stringtie:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq stringtie Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


pipeline=rnaseq
steps=19
protocol=stringtie

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
  prologue "${pipeline}_${protocol}"

   generate_script ${pipeline}_commands_${protocol}.sh \
   -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
   -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
   -t ${protocol}


   ExitCodes+=(["${pipeline}_${protocol}"]="$?")

   if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
     submit ${pipeline}_commands_${protocol}.sh
   fi

   cd ../
fi
## rnaseq.py -t cufflinks:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq cufflinks Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"



pipeline=rnaseq
steps=25
protocol=cufflinks

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
    -t ${protocol}


    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi

## dnaseq.py -t mugqic:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq MUGQIC Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"



pipeline=dnaseq
steps=29
protocol=mugqic

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol}

    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi

## dnaseq.py -t mpileup:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq Mpileup Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"



pipeline=dnaseq
steps=32
protocol=mpileup

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"


    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol}

    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi

## dnaseq_high_coverage:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq High Coverage Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


pipeline=dnaseq_high_coverage
technology=dnaseq
steps=15

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt

    ExitCodes+=(["${pipeline}"]="$?")

    if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
      submit ${pipeline}_commands.sh
    fi

    cd ../
fi

## tumor_pair.py: No inis on most servers yet
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing Tumor Pair Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

#


# $MUGQIC_PIPELINES_HOME/pipelines/tumor_pair/tumor_pair.py \
# -c $MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/tumor_pair/tumor_pair.base.ini $MUGQIC_PIPELINES_HOME/pipelines/tumor_pair/tumor_pair.${server}.ini \
# -r $MUGQIC_INSTALL_HOME/testdata/tumor_pair/readset.tumorPair.txt \
# -p $MUGQIC_INSTALL_HOME/testdata/tumor_pair/pairs.csv \
# -s 1-44 \
# -j $scheduler > tumor_pairCommands.sh

# ExitCodes+=(["tumor_pair"]="$?")


## hicseq.py -t hic:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing HiCSeq HiC Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"




pipeline=hicseq
steps=16
protocol=hic
extra="-e MboI"

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} ${extra}

    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi


## hicseq.py -t capture:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing HiCSeq Capture Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## soft link to capture bed file



pipeline=hicseq
steps=17
protocol=capture
extra="-e MboI"

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    ln -s $MUGQIC_INSTALL_HOME/testdata/hicseq/GSE69600_promoter_capture_bait_coordinates.bed \
    GSE69600_promoter_capture_bait_coordinates.bed

    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol} ${extra}


    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi

## rnaseq_light.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq Light Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"



pipeline=rnaseq_light
technology=rnaseq
steps=7

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${technology}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${technology}.txt

    ExitCodes+=(["${pipeline}"]="$?")

    if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
      submit ${pipeline}_commands.sh
    fi

    cd ../
fi


## rnaseq_denovo_assembly.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq de novo Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"




pipeline=rnaseq_denovo_assembly
technology=rnaseq
steps=23

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${technology}/design.${technology}.txt

    ExitCodes+=(["${pipeline}"]="$?")

    if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
      submit ${pipeline}_commands.sh
    fi

    cd ../
fi

## methylseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing methylseq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"




pipeline=methylseq
steps=15


check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt

    ExitCodes+=(["${pipeline}"]="$?")

    if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
      submit ${pipeline}_commands.sh
    fi

    cd ../
fi


## pacbio_assembly.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing PacBio Assembly Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"




pipeline=pacbio_assembly
technology=pacbio
steps=12


check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}"

    generate_script ${pipeline}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt

    ExitCodes+=(["${pipeline}"]="$?")

    if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
      submit ${pipeline}_commands.sh
    fi

    cd ../
fi


## ampliconseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing AmpliconSeq Dada2 Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"





pipeline=ampliconseq
steps=7
protocol=dada2

check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
    -t ${protocol}

    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing AmpliconSeq Qiime Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"




pipeline=ampliconseq
steps=34
protocol=qiime


check_run
if [[ ${run_pipeline} == 'true' ]] ; then
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_commands_${protocol}.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
    -t ${protocol}


    ExitCodes+=(["${pipeline}_${protocol}"]="$?")

    if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
      submit ${pipeline}_commands_${protocol}.sh
    fi

    cd ../
fi


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Testing GenPipes Command Complete ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


