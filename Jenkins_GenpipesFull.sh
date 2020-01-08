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

}

#pipelines=(chipseq dnaseq rnaseq hicseq methylseq pacbio_assembly ampliconseq  dnaseq_high_coverage
#rnaseq_denovo_assembly rnaseq_light tumor_pair illumina_run_processing)
pipelines=(chipseq dnaseq_mugqic dnaseq_mpileup  rnaseq_stringtie rnaseq_cufflinks  hicseq_hic hicseq_capture methylseq pacbio_assembly ampliconseq_dada2 ampliconseq_qiime  dnaseq_high_coverage  rnaseq_denovo_assembly rnaseq_light tumor_pair illumina_run_processing)

avail (){

  echo available pipeline in the test suite
  (IFS=$'\n' ; echo "${pipelines[*]}" )
}

while getopts "ap:b:c:slu" opt; do
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
      avail
      exit 0
      ;;
    u)
      export UPDATE_MODE=true
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

module load mugqic/python/2.7.14

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
  if [[ ${commit} == '' ]] ; then
    TIMESTAMP=`date +%FT%H.%M.%S` 
    GENPIPES_DIR=${TEST_DIR}/GenPipesFull_${branch}_${TIMESTAMP}
  else
    GENPIPES_DIR=${TEST_DIR}/GenPipesFull_${branch}_${commit}
fi

## set up a dict to collect exit codes:

declare -A ExitCodes=()

## clone GenPipes from bitbucket

if [[ -z ${DEBUG} ]] ; then
  mkdir -p ${GENPIPES_DIR}
  cd ${GENPIPES_DIR}
fi

echo "cloning Genpipes ${branch} from: git@bitbucket.org:mugqic/genpipes.git"

if [ -d "genpipes" ]; then
  rm -rf genpipes
fi

if [[ -z ${DEBUG} ]] ; then
  cd ${GENPIPES_DIR}
  echo cloning to ${GENPIPES_DIR}/genpipes
  git clone --depth 3 --branch ${branch} git@bitbucket.org:mugqic/genpipes.git
  cd genpipes
  git checkout ${commit}

  ## set MUGQIC_PIPELINE_HOME to GenPipes bitbucket install:
  export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
  export MUGQIC_PIPELINES_HOME=${GENPIPES_DIR}/genpipes
fi

if [[ -z ${DEBUG} ]] ; then
  mkdir -p ${GENPIPES_DIR}/scriptTestOutputs
  cd ${GENPIPES_DIR}/scriptTestOutputs
fi

export pipeline
export technology
export run_pipeline
export protocol

prologue () {
  # Folder is named pipeline_protocole
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

  if [[ -z ${SCRIPT_ONLY} ]] ; then
    module purge
      echo submiting $pipeline
      bash ${command}
      echo "${command} submit completed"
    else
      echo "${command} not submitted"
  fi
}

check_run () {
  # if there is not protocol remove the _
  pip=${1%%_}
  run_pipeline=false
  if [[ -z ${PIPELINES} ]]; then
    run_pipeline=true
  else
    if [[ " ${PIPELINES[@]} " =~ " ${pip} " ]]; then
      run_pipeline=true
    fi
  fi
}

## chipseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing ChIPSeq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

pipeline=chipseq
protocol=''

check_run "${pipeline}_${protocol}"
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
protocol=stringtie

check_run "${pipeline}_${protocol}"
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
protocol=stringtie

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
protocol=cufflinks

check_run "${pipeline}_${protocol}"
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
protocol=mugqic

check_run "${pipeline}_${protocol}"
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
protocol=mpileup

check_run "${pipeline}_${protocol}"
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
protocol=''

check_run "${pipeline}_${protocol}"
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
protocol=hic
extra="-e MboI"

check_run "${pipeline}_${protocol}"
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
protocol=capture
extra="-e MboI"

check_run "${pipeline}_${protocol}"
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
protocol=''
technology=rnaseq

check_run "${pipeline}_${protocol}"
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
protocol=''

check_run "${pipeline}_${protocol}"
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
protocol=''


check_run "${pipeline}_${protocol}"
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
protocol=''
technology=pacbio


check_run "${pipeline}_${protocol}"
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
protocol=dada2

check_run "${pipeline}_${protocol}"
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
protocol=qiime


check_run "${pipeline}_${protocol}"
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


