#!/bin/env bash

## Server set up:


## guillaume's rrg account at CC's id is 6007512; the def account id is 6002326; change based on whether we have a RAC allocation on server or not

def=6002326
rrg=6007512

HOST=`hostname`;
DNSDOMAIN=`dnsdomainname`;

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
echo "Starting Genpipes command build test today:  $(date)"
echo "                                    Server:  ${serverName}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## set up environment:

module load mugqic/python/2.7.14

## set up a dict to collect exit codes:
declare -A ExitCodes=()

mkdir -p ${TEST_DIR}/GenPipesCommand
cd ${TEST_DIR}/GenPipesCommand

## clone GenPipes from bitbucket
echo "cloning Genpipes master from: git@bitbucket.org:mugqic/genpipes.git"

if [ -d "genpipes" ]; then
  rm -rf genpipes
fi

git clone git@bitbucket.org:mugqic/genpipes.git


## set MUGQIC_PIPELINE_HOME to GenPipes bitbucket install:
export MUGQIC_INSTALL_HOME=/cvmfs/soft.mugqic/CentOS6
export MUGQIC_PIPELINES_HOME=${TEST_DIR}/GenPipesCommand/genpipes

mkdir -p ${TEST_DIR}/GenPipesCommand/scriptTestOutputs
cd ${TEST_DIR}/GenPipesCommand/scriptTestOutputs


#pipelines=(chipseq dnaseq rnaseq hicseq methylseq pacbio_assembly ampliconseq dnaseq_high_coverage rnaseq_denovo_assembly rnaseq_light tumor_pair illumina_run_processing)

## chipseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing ChIPSeq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/chipseq/chipseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/chipseq/chipseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/chipseq/chipseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/chipseq/readset.chipseq.txt \
-d $MUGQIC_INSTALL_HOME/testdata/chipseq/design.chipseq.txt \
-s 1-19 \
-j $scheduler > chipseqCommands.sh

ExitCodes+=(["chipseq"]="$?")


## rnaseq.py -t stringtie:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq stringtie Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/rnaseq/rnaseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/rnaseq/rnaseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/rnaseq/rnaseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/rnaseq/readset.rnaseq.txt \
-d $MUGQIC_INSTALL_HOME/testdata/rnaseq/design.rnaseq.txt \
-s 1-19 \
-t stringtie \
-j $scheduler > rnaseqCommands.sh

ExitCodes+=(["rnaseq_stringtie"]="$?")


## rnaseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq cufflinks Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/rnaseq/rnaseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/rnaseq/rnaseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/rnaseq/rnaseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/rnaseq/readset.rnaseq.txt \
-d $MUGQIC_INSTALL_HOME/testdata/rnaseq/design.rnaseq.txt \
-s 1-25 \
-t cufflinks \
-j $scheduler > rnaseqCommands.sh

ExitCodes+=(["rnaseq_cufflinks"]="$?")

## dnaseq.py -t mugqic:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq MUGQIC Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/dnaseq/readset.dnaseq.txt \
-s 1-29 \
-t mugqic \
-j $scheduler > dnaseqCommands_mugqic.sh

ExitCodes+=(["dnaseq_mugqic"]="$?")

## dnaseq.py -t mpileup:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq Mpileup Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/dnaseq/dnaseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/dnaseq/readset.dnaseq.txt \
-s 1-33 \
-t mpileup \
-j $scheduler > dnaseqCommands_mpileup.sh

ExitCodes+=(["dnaseq_mpileup"]="$?")

## dnaseq.py -t mpileup:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing DNASeq High Coverage Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/dnaseq_high_coverage/dnaseq_high_coverage.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/dnaseq_high_coverage/dnaseq_high_coverage.base.ini $MUGQIC_PIPELINES_HOME/pipelines/dnaseq_high_coverage/dnaseq_high_coverage.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/dnaseq/readset.dnaseq.txt \
-s 1-15 \
-j $scheduler > dnaseq_high_coverageCommands.sh

ExitCodes+=(["dnaseq_high_coverage"]="$?")

## tumor_pair.py: No inis on most servers yet
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing Tumor Pair Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
# echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


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

$MUGQIC_PIPELINES_HOME/pipelines/hicseq/hicseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/hicseq/hicseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/hicseq/hicseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/hicseq/readset.hicseq.txt \
-s 1-16 \
-t hic \
-e MboI \
-j $scheduler > hicseqCommands_hic.sh

ExitCodes+=(["hicseq_hic"]="$?")


## hicseq.py -t capture:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing HiCSeq Capture Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## soft link to capture bed file
ln -s $MUGQIC_INSTALL_HOME/testdata/hicseq/GSE69600_promoter_capture_bait_coordinates.bed GSE69600_promoter_capture_bait_coordinates.bed

$MUGQIC_PIPELINES_HOME/pipelines/hicseq/hicseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/hicseq/hicseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/hicseq/hicseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/hicseq/readset.hicseq.txt \
-s 1-17 \
-t capture \
-e MboI \
-j $scheduler > hicseqCommands_capture.sh

ExitCodes+=(["hicseq_capture"]="$?")


## rnaseq_light.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq Light Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/rnaseq_light/rnaseq_light.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/rnaseq_light/rnaseq_light.base.ini $MUGQIC_PIPELINES_HOME/pipelines/rnaseq_light/rnaseq_light.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/rnaseq/readset.rnaseq.txt \
-d $MUGQIC_INSTALL_HOME/testdata/rnaseq/design.rnaseq.txt \
-s 1-7 \
-j $scheduler > rnaseqLightCommands.sh

ExitCodes+=(["rnaseq_light"]="$?")


## rnaseq_denovo_assembly.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing RNASeq de novo Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

$MUGQIC_PIPELINES_HOME/pipelines/rnaseq_denovo_assembly/rnaseq_denovo_assembly.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/rnaseq_denovo_assembly/rnaseq_denovo_assembly.base.ini $MUGQIC_PIPELINES_HOME/pipelines/rnaseq_denovo_assembly/rnaseq_denovo_assembly.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/rnaseq/readset.rnaseq.txt \
-d $MUGQIC_INSTALL_HOME/testdata/rnaseq/design.rnaseq.txt \
-s 1-23 \
-j $scheduler > rnaseqDeNovoCommands.sh

ExitCodes+=(["rnaseq_denovo_assembly"]="$?")


## methylseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing methylseq Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

$MUGQIC_PIPELINES_HOME/pipelines/methylseq/methylseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/methylseq/methylseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/methylseq/methylseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/methylseq/readset.methylseq.txt \
-s 1-15 \
-j $scheduler > methylseq.sh

ExitCodes+=(["methylseq"]="$?")


## pacbio_assembly.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing PacBio Assembly Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

$MUGQIC_PIPELINES_HOME/pipelines/pacbio_assembly/pacbio_assembly.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/pacbio_assembly/pacbio_assembly.base.ini $MUGQIC_PIPELINES_HOME/pipelines/pacbio_assembly/pacbio_assembly.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/pacbio/readset.pacbio.txt \
-s 1-12 \
-j $scheduler > pacbioCommands.sh

ExitCodes+=(["pacbio_assembly"]="$?")


## ampliconseq.py:
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing AmpliconSeq Dada2 Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# design required!:
$MUGQIC_PIPELINES_HOME/pipelines/ampliconseq/ampliconseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/ampliconseq/ampliconseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/ampliconseq/ampliconseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/ampliconseq/readset.ampliconseq.txt \
-d $MUGQIC_INSTALL_HOME/testdata/ampliconseq/design.ampliconseq.txt \
-s 1-7 \
-t dada2 \
-j $scheduler > ampliconseqDadaCommands.sh

ExitCodes+=(["ampliconseq_dada2"]="$?")

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now testing AmpliconSeq Qiime Command Creation ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


$MUGQIC_PIPELINES_HOME/pipelines/ampliconseq/ampliconseq.py \
-c $MUGQIC_PIPELINES_HOME/pipelines/ampliconseq/ampliconseq.base.ini $MUGQIC_PIPELINES_HOME/pipelines/ampliconseq/ampliconseq.${server}.ini \
-r $MUGQIC_INSTALL_HOME/testdata/ampliconseq/readset.ampliconseq.txt \
-s 1-34 \
-t qiime \
-j $scheduler > ampliconseqQiimeCommands.sh

ExitCodes+=(["ampliconseq_qiime"]="$?")

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Now Checking if DEV exists in ini files ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


## grep $MUGQIC_INSTALL_HOME_DEV or mugqic_dev
Dev_ini_status=0

for iniFile in $(ls $MUGQIC_PIPELINES_HOME/pipelines/*/*.ini); do
  found=$(grep -E 'MUGQIC_INSTALL_HOME_DEV|mugqic_dev' $iniFile)
  if [ ! -z "$found" ]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "WARNING: ${iniFile} might contain Dev modules..."
    echo "Dev modules Found: ${found}"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    Dev_ini_status=2
  fi
done

if [ "$Dev_ini_status" -eq "0" ]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo ""
    echo "Passed!  No Ini files contain MUGQIC_INSTALL_HOME_DEV or mugqic_dev"
    echo ""
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

fi


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Printing Exit Codes for each pipeline ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


echo "Date: $(date)"
echo "Server:  ${serverName}"
echo ""

status=0
for code in "${!ExitCodes[@]}"; do
    echo "$code: ${ExitCodes[$code]}"
    if [ "${ExitCodes[$code]}" -ne "0" ];
        then status=2;
    fi
done


if [ "$Dev_ini_status" -ne "0" ];
    then
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "WARNING: Some ini files might contain Dev modules. Please check above for list."
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
fi



echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Testing GenPipes Command Complete ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


exit $status
