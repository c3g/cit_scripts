#! /bin/bash

module load mugqic/python/2.7.14 mugqic/genpipes

control_c() {
  exit 0
}

BRANCH=dev

if [ "$#" -ne 1 ] ; then 
 echo "$0 <path of cit outputs>"
 exit 1
fi 

RESULT_PATH=$1
latest_dev=$(realpath  "${RESULT_PATH}")
cd $latest_dev && mkdir -p cit_out && cd cit_out
trap control_c SIGINT
list=$(find ${latest_dev}  -maxdepth 3  -type d -name 'job_output' | xargs -L 1 -I@ sh -c "ls -t1 @/*job* | head -n 1 ")
for jl in $list ; do
  out=$( echo "$jl" | sed 's|.*scriptTestOutputs/\(.*\)/job_output.*|\1|g' )
  echo processing $out 
  $MUGQIC_PIPELINES_HOME/utils/log_report.py  --loglevel CRITICAL -q --tsv $out.tsv $jl
done 
grep -v   "COMPLETED\+[[:space:]]\+COMPLETED\+[[:space:]]\+COMPLETED" *tsv | grep -v "log_from_job" | grep -v CANCELLED | sort -u -t: -k1,1
