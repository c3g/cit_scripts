  #!/bin/bash
job_list=$(cat  $SCRIPT_OUTPUT/*/chunk/*out  | awk -F'=' '{printf(":%s",$2)}'| sed 's/ //g')
# job_list=$(cat /tmp/all | awk -F'=' '{printf(":%s",$1)}'| sed 's/ //g')

tmp_script=$(mktemp)

cat > $tmp_script << EOF
#! /bin/bash
#SBATCH -d afterany${job_list}
#SBATCH --mem 500M
#SBATCH --output=log_report.log

module load python/3

control_c() {
  exit 0
}


latest_dev=$(realpath  "${SCRIPT_OUTPUT}")



mkdir -p \${latest_dev}/cit_out && cd \${latest_dev}/cit_out

trap control_c SIGINT
list=\$(find \${latest_dev}  -maxdepth 3  -type d -name 'job_output' | xargs -L 1 -I@ sh -c "ls -t1 @/*job* | head -n 1 ")

for jl in \$list ; do
  out=\$( echo "\$jl" | sed 's|.*scriptTestOutputs/\(.*\)/job_output.*|\1|g' )
  echo processing \$out
  \$MUGQIC_PIPELINES_HOME/utils/log_report.py  --loglevel CRITICAL  --tsv \$out.tsv \$jl
done

## curl call to jenkens server via ssh
JENKIN_URL=https://jenkins.vhost38.genap.ca/view/s2.Beluga/job/report_on_full_run/buildWithParameters
echo "########################################################" > digest.log
grep -v   "COMPLETED\+[[:space:]]\+COMPLETED\+[[:space:]]\+COMPLETED" *tsv \
| grep -v "log_from_job" | grep -v CANCELLED >> digest.log
echo "########################################################" >> digest.log
cat \${SLURM_SUBMIT_DIR}/log_report.log >> digest.log
cat digest.log | ssh ${HOSTNAME} curl -k -X GET --form '"logfile=<-"'  "\$JENKIN_URL?token=\$API_TOKEN"
EOF

sbatch -A ${RAP_ID:-def-bourqueg} $tmp_script
