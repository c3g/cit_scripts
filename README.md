# cit_scripts

## Run a test


## Add a new pipeline to the Jenkins_GenpipesFull.sh test suite

Here is a template, modify it so it can run you pipeline and add it above the `# Add new test above ^^` 
line in the script.

```bash 
pipeline=<my new pipeline>
protocol=<new protocole version> # sometime there is no protocole 

check_run "${pipeline}_${protocol}"  # If there is no protocol, execute check_run "${pipeline}"
if [[ ${run_pipeline} == 'true' ]] ; then
    # this creates the directory where the pipeline will be ran
    
    prologue "${pipeline}_${protocol}"

    generate_script ${pipeline}_${protocol}_commands.sh \
    -r $MUGQIC_INSTALL_HOME/testdata/${pipeline}/readset.${pipeline}_${protocol}.txt \
    -t ${protocol} 

    submit

fi
```

`check_run <pipeline>` check is the pipeline need to be run (used by the -p <pipeline> option). 

`prologue <folder>` creates the folder where the tests for the pipeline is ran. 

`generate_script <script output name> [<genpipes option>, ...]` will run the `$pipleine.py` script with the `${pipeline
}.base
.ini` file, the local `${pipeline}.<cluster>.ini` file and the `cit.ini` file found in the pipeline's Genpipes folder
 along with all <genpipes options>, typically a reasdset input.  The output script is stored int the folder created
  by the prologue. 

`submit` execute the script generated by generate_script`
