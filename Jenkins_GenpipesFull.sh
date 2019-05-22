#!/bin/env bash

## Server set up:


## guillaume's rrg account at CC's id is 6007512; the def account id is 6002326; change based on whether we have a RAC allocation on server or not

def=6002326
rrg=6007512

HOST=`hostname`;
DNSDOMAIN=`dnsdomainname`;

export GENPIPES_CIT=

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

fi


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Starting Genpipes Full Command tests today:  $(date)"
echo "                                    Server:  ${serverName}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## set up environment:

module load mugqic/python/2.7.14


## set up a dict to collect exit codes:
declare -A ExitCodes=()

mkdir -p ${TEST_DIR}/GenPipesFull
cd ${TEST_DIR}/GenPipesFull

## clone GenPipes from bitbucket
branch=master
echo "cloning Genpipes ${branch} from: git@bitbucket.org:mugqic/genpipes.git"

if [ -d "genpipes" ]; then
  rm -rf genpipes
fi

git clone --depth 1 --branch ${branch} git@bitbucket.org:mugqic/genpipes.git


## set MUGQIC_PIPELINE_HOME to GenPipes bitbucket install:
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
export MUGQIC_PIPELINES_HOME=${TEST_DIR}/GenPipesFull/genpipes

mkdir -p ${TEST_DIR}/GenPipesFull/scriptTestOutputs
cd ${TEST_DIR}/GenPipesFull/scriptTestOutputs


#pipelines=(chipseq dnaseq rnaseq hicseq methylseq pacbio_assembly ampliconseq dnaseq_high_coverage rnaseq_denovo_assembly rnaseq_light tumor_pair illumina_run_processing)

## chipseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing ChIPSeq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

pipeline=chipseq
steps=19

if [ -d "${pipeline}" ]; then
  rm -rf ${pipeline}
fi

mkdir -p ${pipeline}
cd ${pipeline}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_INSTALL_HOME/testdata/${pipeline}/${pipeline}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler > ${pipeline}_commands.sh

ExitCodes+=(["${pipeline}"]="$?")

if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands.sh
  echo "${pipeline} jobs submitted"
fi

cd ../

## rnaseq.py -t stringtie:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq stringtie Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

module load mugqic/python/2.7.14

pipeline=rnaseq
steps=19
protocol=stringtie


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi

mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../

## rnaseq.py -t cufflinks:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq cufflinks Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

module load mugqic/python/2.7.14

pipeline=rnaseq
steps=25
protocol=cufflinks


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi

mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../


## dnaseq.py -t mugqic:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq MUGQIC Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

module load mugqic/python/2.7.14

pipeline=dnaseq
steps=29
protocol=mugqic


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi


mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

${MUGQIC_PIPELINES_HOME}/pipelines/${pipeline}/${pipeline}.py \
-c ${MUGQIC_PIPELINES_HOME}/pipelines/${pipeline}/${pipeline}.base.ini \
${MUGQIC_PIPELINES_HOME}/pipelines/${pipeline}/${pipeline}.${server}.ini \
${MUGQIC_PIPELINES_HOME}/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../


## dnaseq.py -t mpileup:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq Mpileup Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

module load mugqic/python/2.7.14

pipeline=dnaseq
steps=33
protocol=mpileup


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi


mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../


## dnaseq_high_coverage:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq High Coverage Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


module load mugqic/python/2.7.14


pipeline=dnaseq_high_coverage
technology=dnaseq
steps=15


if [ -d "${pipeline}" ]; then
  rm -rf ${pipeline}
fi

mkdir -p ${pipeline}
cd ${pipeline}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt \
-s 1-${steps} \
-j $scheduler > ${pipeline}_commands.sh

ExitCodes+=(["${pipeline}"]="$?")

if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands.sh
  echo "${pipeline} jobs submitted"
fi

cd ../


## tumor_pair.py: No inis on most servers yet
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing Tumor Pair Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# module load mugqic/python/2.7.14


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


module load mugqic/python/2.7.14

pipeline=hicseq
steps=16
protocol=hic
extra="-e MboI"


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi


mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_INSTALL_HOME/testdata/${pipeline}/hicseq.GM12878_chr19.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} ${extra} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../



## hicseq.py -t capture:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing HiCSeq Capture Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## soft link to capture bed file

module load mugqic/python/2.7.14

pipeline=hicseq
steps=17
protocol=capture
extra="-e MboI"


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi

mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}
ln -s $MUGQIC_INSTALL_HOME/testdata/hicseq/GSE69600_promoter_capture_bait_coordinates.bed GSE69600_promoter_capture_bait_coordinates.bed


$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} ${extra} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../


## rnaseq_light.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq Light Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

module load mugqic/python/2.7.14

pipeline=rnaseq_light
technology=rnaseq
steps=7


if [ -d "${pipeline}" ]; then
  rm -rf ${pipeline}
fi

mkdir -p ${pipeline}
cd ${pipeline}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt \
-d $MUGQIC_INSTALL_HOME/testdata/${technology}/design.${technology}.txt \
-s 1-${steps} \
-j $scheduler > ${pipeline}_commands.sh

ExitCodes+=(["${pipeline}"]="$?")

if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands.sh
  echo "${pipeline} jobs submitted"
fi

cd ../



## rnaseq_denovo_assembly.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq de novo Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


module load mugqic/python/2.7.14

pipeline=rnaseq_denovo_assembly
technology=rnaseq
steps=23


if [ -d "${pipeline}" ]; then
  rm -rf ${pipeline}
fi


mkdir -p ${pipeline}
cd ${pipeline}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt \
-d $MUGQIC_INSTALL_HOME/testdata/${technology}/design.${technology}.txt \
-s 1-${steps} \
-j $scheduler > ${pipeline}_commands.sh

ExitCodes+=(["${pipeline}"]="$?")

if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands.sh
  echo "${pipeline} jobs submitted"
fi

cd ../


## methylseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing methylseq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


module load mugqic/python/2.7.14

pipeline=methylseq
steps=15


if [ -d "${pipeline}" ]; then
  rm -rf ${pipeline}
fi

mkdir -p ${pipeline}
cd ${pipeline}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler > ${pipeline}_commands.sh

ExitCodes+=(["${pipeline}"]="$?")

if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands.sh
  echo "${pipeline} jobs submitted"
fi

cd ../



## pacbio_assembly.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing PacBio Assembly Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


module load mugqic/python/2.7.14

pipeline=pacbio_assembly
technology=pacbio
steps=12


if [ -d "${pipeline}" ]; then
  rm -rf ${pipeline}
fi

mkdir -p ${pipeline}
cd ${pipeline}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${technology}/readset.${technology}.txt \
-s 1-${steps} \
-j $scheduler > ${pipeline}_commands.sh

ExitCodes+=(["${pipeline}"]="$?")

if [ ${ExitCodes["${pipeline}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands.sh
  echo "${pipeline} jobs submitted"
fi

cd ../



## ampliconseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing AmpliconSeq Dada2 Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


module load mugqic/python/2.7.14


pipeline=ampliconseq
steps=7
protocol=dada2

if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi

mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-d $MUGQIC_INSTALL_HOME/testdata/${pipeline}/design.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing AmpliconSeq Qiime Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


module load mugqic/python/2.7.14

pipeline=ampliconseq
steps=34
protocol=qiime


if [ -d "${pipeline}_${protocol}" ]; then
  rm -rf ${pipeline}_${protocol}
fi

mkdir -p ${pipeline}_${protocol}
cd ${pipeline}_${protocol}

$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.base.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/${pipeline}.${server}.ini \
$MUGQIC_PIPELINES_HOME/pipelines/${pipeline}/cit.ini \
-r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}.txt \
-s 1-${steps} \
-j $scheduler \
-t ${protocol} > ${pipeline}_commands_${protocol}.sh

ExitCodes+=(["${pipeline}_${protocol}"]="$?")

if [ ${ExitCodes["${pipeline}_${protocol}"]} -eq 0 ]; then
  module purge
  bash ${pipeline}_commands_${protocol}.sh
  echo "${pipeline}_${protocol} jobs submitted"
fi

cd ../



echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Testing GenPipes Command Complete ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


