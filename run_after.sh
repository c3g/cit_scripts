#!/bin/bash


usage (){

echo
echo "usage: $0 create log report for all pipelines ran in interation testing"
echo
echo "   -h                         Print this help "
echo "   -j                         Sends the report to jenkins"
echo "   -p                         Path to the directory containing the pipeline output ending by scriptTestOutputs"

}

while getopts "j::ph" opt; do
  case $opt in
    j)
      JENKINS=1
      ;;
    p)
      path="$OPTARG"
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



job_list=$(cat "$path"/*/chunk/*out  | awk -F'=' '{printf(":%s",$2)}'| sed 's/ //g')
tmp_script=$(mktemp)
# for debuging
# job_list=$(cat /tmp/all | awk -F'=' '{printf(":%s",$2)}'| sed 's/ //g')
# tmp_script=/tmp/tata


if [[ -n $JENKINS ]] ; then
## curl call to jenkens server via ssh
  SEND_TO_J=$(cat << EOF
JENKINS_URL=https://jenkins.vhost38.genap.ca/job/report_on_full_run/buildWithParameters
curl -k -X GET --form logfile=@digest.log  "\$JENKINS_URL?token=\$API_TOKEN"
EOF
)
fi


cat > "$tmp_script" << EOF
#!/bin/bash
#SBATCH -d afterany${job_list}
#SBATCH --mem 500M
#SBATCH --time 00:30:00
#SBATCH --output=log_report.log

module load python/3

control_c() {
  exit 0
}


latest_dev=$(realpath  "${path}")


mkdir -p \${latest_dev}/cit_out && cd \${latest_dev}/cit_out

trap control_c SIGINT
list=\$(find \${latest_dev}  -maxdepth 3  -type d -name 'job_output' | xargs -I@ sh -c "ls -t1 @/*job* | head -n 1 ")

for jl in \$list ; do
  out=\$( echo "\$jl" | sed 's|.*scriptTestOutputs/\(.*\)/job_output.*|\1|g' )
  echo processing \$out
  \${MUGQIC_PIPELINES_HOME}/utils/log_report.py  --loglevel CRITICAL  --tsv \$out.tsv \$jl
done

echo "########################################################" > digest.log
grep -v   "COMPLETED\+[[:space:]]\+COMPLETED\+[[:space:]]\+COMPLETED" *tsv \
| grep -v "log_from_job" | grep -e 'TIMEOUT' -e 'FAILED' -e 'OUT_OF_MEMORY' >> digest.log
echo "########################################################" >> digest.log
cat \${SLURM_SUBMIT_DIR}/log_report.log >> digest.log
${SEND_TO_J}
EOF

sbatch -A "${RAP_ID:-def-bourqueg}" "$tmp_script"

