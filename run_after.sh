#!/bin/bash

SCHEDULER=slurm

usage (){

echo
echo "usage: $0 create log report for all pipelines ran in interation testing"
echo
echo "   -h                         Print this help "
echo "   -j                         Sends the report to jenkins"
echo "   -p                         Path to the directory containing the cit result"
echo "   -S                         Scheduler running on the cluster (slurm or pbs) default=$SCHEDULER"

}

while getopts "p:S:jh" opt; do
  case $opt in
    j)
      JENKINS=1
      ;;
    p)
      path="$OPTARG"
      ;;
    S)
      SCHEDULER=${OPTARG}
      if [[ ${SCHEDULER} != 'slurm'  && ${SCHEDULER} != 'pbs' ]] ;then
        echo "only slurm and pbs scheduler are supported"
        usage
        exit 1
      fi
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

tmp_script=$(mktemp)
# for debuging
# job_list=$(cat /tmp/all | awk -F'=' '{printf(":%s",$2)}'| sed 's/ //g')
# tmp_script=/tmp/tata


if [[ -n $JENKINS ]] ; then
## curl call to jenkins server via ssh
  SEND_TO_J=$(cat << EOF
JENKINS_URL=https://jenkins.c3g-app.sd4h.ca/job/report_on_full_run/buildWithParameters
ssh ${HOSTNAME} curl -k -X GET --form logfile=@${path}/scriptTestOutputs/cit_out/digest.log  "\$JENKINS_URL?token=\$API_TOKEN"
EOF
)
fi

if [[ $SCHEDULER == 'pbs' ]] ; then
  # This is needed for Abacus/PBS because the jobs already done can't be used as deopen dependency
  # So here we get the jobid from the last chunk of each pipeline and use them as dependency as it shouldn't be completed when cit script ends
  job_list=""
  for pipeline_dir in $(find "$path"/scriptTestOutputs -maxdepth 1 -type d); do
    if find "$pipeline_dir/chunk" -maxdepth 1 -name "chunk_*.out" 2>/dev/null | grep -q .; then
      latest_file=$(find "$pipeline_dir/chunk" -maxdepth 1 -name "chunk_*.out" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d' ' -f2-)
      jobid=$(awk -F'=' '{print $2}' "$latest_file" | tail -n 1 | sed 's/ //g')
      job_list="${job_list}:${jobid}"
    fi
  done
  cat > "$tmp_script" << EOF
#!/bin/bash
#PBS -W depend=afterany${job_list}
#PBS -l mem=500mb
#PBS -l walltime=00:30:00
#PBS -o log_report.log

control_c() {
  exit 0
}

latest_dev=$(realpath  "${path}/scriptTestOutputs")
source ${path}/genpipes/genpipes_venv/bin/activate

mkdir -p \${latest_dev}/cit_out && cd \${latest_dev}/cit_out

trap control_c SIGINT
list=\$(find \${latest_dev} -maxdepth 3 -type d -name 'job_output' | xargs -I@ sh -c "ls -t1 @/*job* | head -n 1 ")

for jl in \$list ; do
  out=\$( echo "\$jl" | sed 's|.*scriptTestOutputs/\(.*\)/job_output.*|\1|g' )
  echo processing \$out
  genpipes tools log_report --tsv \$out.tsv \$jl
done

echo "########################################################" > digest.log
grep -v   "COMPLETED\+[[:space:]]\+COMPLETED\+[[:space:]]\+COMPLETED" *tsv \
| grep -v "log_from_job" | grep -e 'TIMEOUT' -e 'FAILED' -e 'OUT_OF_MEMORY' >> digest.log
echo "########################################################" >> digest.log
cat \${SLURM_SUBMIT_DIR}/log_report.log >> digest.log
${SEND_TO_J}
EOF
  qsub "$tmp_script"
# slurm
else
  job_list=$(cat "$path"/scriptTestOutputs/*/chunk/*out  | awk -F'=' '{printf(":%s",$2)}'| sed 's/ //g')
  cat > "$tmp_script" << EOF
#!/bin/bash
#SBATCH -d afterany${job_list}
#SBATCH --mem 500M
#SBATCH --time 00:30:00
#SBATCH --output=log_report.log

control_c() {
  exit 0
}

latest_dev=$(realpath  "${path}/scriptTestOutputs")
source ${path}/genpipes/genpipes_venv/bin/activate

mkdir -p \${latest_dev}/cit_out && cd \${latest_dev}/cit_out

trap control_c SIGINT
list=\$(find \${latest_dev} -maxdepth 3 -type d -name 'job_output' | xargs -I@ sh -c "ls -t1 @/*job* | head -n 1 ")

for jl in \$list ; do
  out=\$( echo "\$jl" | sed 's|.*scriptTestOutputs/\(.*\)/job_output.*|\1|g' )
  echo processing \$out
  genpipes tools log_report --tsv \$out.tsv \$jl
done

echo "########################################################" > digest.log
grep -v   "COMPLETED\+[[:space:]]\+COMPLETED\+[[:space:]]\+COMPLETED" *tsv \
| grep -v "log_from_job" | grep -e 'TIMEOUT' -e 'FAILED' -e 'OUT_OF_MEMORY' >> digest.log
echo "########################################################" >> digest.log
cat \${SLURM_SUBMIT_DIR}/log_report.log >> digest.log
${SEND_TO_J}
EOF
  sbatch -A "${RAP_ID:-def-bourqueg}" "$tmp_script"
fi
