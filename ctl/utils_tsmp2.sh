#!/usr/bin/env bash
# Contains functions for TSMP2-WFE
#
# Included functions:
# sim_calc_numberofproc - calculate number of processors for TSMP2 application
##

# calculate number of processors for TSMP2 application
sim_calc_numberofproc(){

# calculate needed variables TODO: take LC_NUMERIC into account
ico_proc=$( printf %.0f $(echo "$ico_node * $npnode" | bc -l))
clm_proc=$( printf %.0f $(echo "$clm_node * $npnode" | bc -l))
pfl_proc_tmp=$( printf %.0f $(echo "$pfl_node * $npnode" | bc -l))
pfl_proc_sqrt=$(echo "sqrt($pfl_proc_tmp)" | bc -l)
pfl_procY=$((${pfl_proc_sqrt%.*} + (2 - ${pfl_proc_sqrt%.*} % 2))) # go to next num of 2
pfl_procX=$(($pfl_proc_tmp/$pfl_procY))
pfl_proc=$(($pfl_procY*$pfl_procX))
unset pfl_proc_tmp pfl_proc_sqrt

# set <comp>_proc to zero based on modelid
if [[ "${modelid}" != *icon* ]]; then
   ico_node=0
   ico_proc=0
fi
if [[ "${modelid}" != *eclm* ]]; then
   clm_node=0
   clm_proc=0
fi
if [[ "${modelid}" != *parflow* ]]; then
   pfl_node=0
   pfl_proc=0
fi

tot_proc=$(($ico_proc+$clm_proc+$pfl_proc))
tot_node=$(echo $(echo "$ico_node+$clm_node+$pfl_node" | bc -l) | sed -e 's/\.0*$//;s/\.[0-9]*$/ + 1/' | bc) # ceiling

} # sim_calc_numberofproc

# check if oasis is active/true
check_run_oasis() {
  local model_id
  local comp_models=("icon" "eclm" "parflow")
  local model_count=0

  model_id=$(echo ${MODEL_ID} | tr '[:upper:]' '[:lower:]')

  # Split the identifier into individual elements
  IFS='-' read -r -a elements <<< "$model_id"

  # Check for each component model
  for comp_model in "${comp_models[@]}"; do
    for element in "${elements[@]}"; do
      if [ "$element" == "$comp_model" ]; then
#        ((model_count++))
         model_count=$((model_count+1))
      fi
    done
  done

  # Return true if at least 2 components are found
  if [ "$model_count" -ge 2 ]; then
    echo "true"
  else
    echo "false"
  fi
} # check_run_oasis

# check var defaults
check_var_def() {
  local var_name="$1"
  local default="$2"
  local message="$3"
  local cur_value="${!var_name}"

  # take default value when var_name is not set yet
  if [ -z "$cur_value" ]; then
    cur_value="$default"
    eval "$var_name=\"$cur_value\""
    if [ -n "$message" ]; then
      echo "$message"${!var_name}
    fi
  fi
} # check_var_def

logging_job_status(){
  local step="$1"

  if [ "$joblog" = true ]; then
    job_id=$SLURM_JOB_ID
    job_state=$(scontrol show job $job_id | grep "JobState=" | cut -d= -f2 | cut -d' ' -f1)
    printf "%10s %8s %3s %15s %14s %10s %10s %14s %8s\n" "${expid}" "${caseid}" "${step}" "${modelid}" \
        "${dateshort}" "${job_id}" "${job_state}" "$(date '+%Y%m%d%H%M%S')" $(date -u -d "0 $timeend sec - $timestart sec" +"%H:%M:%S") \
        >> ${ctl_dir}/job_status.log
  fi
} # logging_job_status
