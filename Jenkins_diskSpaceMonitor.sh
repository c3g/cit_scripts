#!/bin/env bash

## Server set up:

## will issue warning at threshold
threshold=95
exit_status=0

## guillaume's rrg account at CC's id is 6007512; the def account id is 6002326; change based on whether we have a RAC allocation on server or not

def=6002326
def_id=def-bourqueg
rrg=6007512
rrg_id=rrg-bourqueg-ad

HOST=`hostname`;
DNSDOMAIN=`dnsdomainname`;

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ $HOST == abacus* || $DNSDOMAIN == ferrier.genome.mcgill.ca ]]; then

  export TEST_DIR=/lb/project/mugqic/projects/
  export serverName=Abacus
  export server=abacus

elif [[ $HOST == lg-* || $DNSDOMAIN == guillimin.clumeq.ca ]]; then

  export TEST_DIR=/genfs/C3G/projects/
  export serverName=guillimin
  export server=CC
  export id=${rrg_id}

elif [[ $HOST == ip* ]]; then 

  export TEST_DIR=/project/${rrg}/C3G/projects/
  export serverName=mp2b
  export server=CC
  export id=${rrg_id}

elif [[ $HOST == cedar* || $DNSDOMAIN == cedar.computecanada.ca ]]; then

  export TEST_DIR=/project/${rrg}/C3G/projects/
  export serverName=cedar
  export server=CC
  export id=${rrg_id}

elif [[ $HOST == gra-* || $DNSDOMAIN == graham.sharcnet ]]; then

  export TEST_DIR=/project/${def}/C3G/projects/
  export serverName=graham
  export server=CC
  export id=${def_id}

elif [[ $HOST == beluga* || $DNSDOMAIN == beluga.computecanada.ca ]]; then
  export TEST_DIR=/project/${rrg}/C3G/projects/
  export serverName=beluga
  export server=CC
  export id=${rrg_id}

fi

##### Functions:

unit_tranform() {
val=$1
if [[ $val == *k ]]; then
  x0=$(echo $val | sed 's/k//g')
  x=$(($x0 * 1024))
elif [[ $val == *M ]]; then
  x0=$(echo $val | sed 's/M//g')
  x=$(($x0 * 1024 * 1024))
elif [[ $val == *G ]]; then
  x0=$(echo $val | sed 's/G//g')
  x=$(($x0 * 1024 * 1024 * 1024))
elif [[ $val == *T ]]; then
  x0=$(echo $val | sed 's/T//g')
  x=$(($x0 * 1024 * 1024 * 1024 * 1024))
else
  x=$val
fi

echo $x
}


##### Main:


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Starting Server Usage Monitoring Script today:  $(date)"
echo "                                        Server:  ${serverName}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"




echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    "
echo "                                Checking System Overall Usage:"
echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    "



if [[ $server == abacus ]]; then
  cd $TEST_DIR 
  abaquota -t 2> /dev/null
  used_space=$(abaquota -t 2> /dev/null | grep project | awk '{print($2)}')
  used_space_raw=${used_space}"T"
  avail_space=$(abaquota -t 2> /dev/null | grep project | awk '{print($3)}')
  avail_space_raw=${avail_space}"T"
  perc_space=$(awk "BEGIN {printf \"%.2f\",${used_space}*100/${avail_space}}")

elif [[ $server == CC ]]; then 
  diskusage_report 2> /dev/null
  used_space_raw=$(diskusage_report 2> /dev/null | grep $id | awk '{print($4)}' | awk 'BEGIN {FS="/"} { print $1}')
  used_space=$(unit_tranform $used_space_raw)
  avail_space_raw=$(diskusage_report 2> /dev/null | grep $id | awk '{print($4)}' | awk 'BEGIN {FS="/"} { print $2}')
  avail_space=$(unit_tranform $avail_space_raw)
  used_fileNum_raw=$(diskusage_report 2> /dev/null | grep $id | awk '{print($5)}' | awk 'BEGIN {FS="/"} { print $1}')
  used_fileNum=$(unit_tranform $used_fileNum_raw)
  avail_fileNum_raw=$(diskusage_report 2> /dev/null | grep $id | awk '{print($5)}' | awk 'BEGIN {FS="/"} { print $2}')
  avail_fileNum=$(unit_tranform $avail_fileNum_raw)
  perc_space=$(awk "BEGIN {printf \"%.2f\",${used_space}*100/${avail_space}}")
  perc_fileNum=$(awk "BEGIN {printf \"%.2f\",${used_fileNum}*100/${avail_fileNum}}")

fi



echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    "
echo ""
echo "Space used on ${serverName} as part of ${id}: ${used_space_raw} from ${avail_space_raw} ==>  ${perc_space} percent" 
if [[ $server == CC ]]; then
  echo "File # used on ${serverName} as part of ${id}: ${used_fileNum_raw} from ${avail_fileNum_raw} ==>  ${perc_fileNum} percent"
fi
echo ""
echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    "


if [ "${perc_space%.*}" -gt "$threshold" ]; then
  echo "WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING!"
  echo "WARNING! Space usage has exceeded threshold of ${threshold} "
  echo "WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING!"
  exit_status=1
fi

if [[ $server == CC ]]; then
  if [ "${perc_fileNum%.*}" -gt "$threshold" ]; then
    echo "WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING!"
    echo "WARNING! File number has exceeded threshold of ${threshold} "
    echo "WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING!"
    exit_status=1
  fi
fi


echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    "
echo "                                Checking space Usage by folder:"
echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    "

module load python/3.7
tmpfile=$(mktemp)
echo ********** UNSORTED **********
ls -d   $TEST_DIR/* | parallel -P 10 python3 ${SCRIPT_DIR}/size.py 2>/dev/null | tee ${tmpfile}  
echo **********  SORTED  **********
sort -hr ${tmpfile}



echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Jenkins Disk Space Monitor is Complete ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


exit $exit_status
