#!/usr/bin/env bash
# Contains functions for TSMP2-WFE
#
# Included functions:
# sim_calc_numberofproc - calculate number of processors for TSMP2 application
# check_run_oasis - check if simulation is running in coupled mode
# check_var_def - check if variable is defined and if not take default and printing message
# logging_job_status - log information about the job into job_status.log
# parse_config_file - parser to read in ini/conf-files
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


# input 1: filename of conf-file input 2: section (optional)
parse_config_file() {
    local config_file="$1"
    local target_section="${2:-default}"
    local current_section="default"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}" # remove comments including in-line comments
        line="${line%"${line##*[![:space:]]}"}" # remove spaces
        line="${line#"${line%%[![:space:]]*}"}" # remove spaces
        [[ -z "$line" ]] && continue # skip empty lines

        # get section
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        # only parse target section
        if [[ "$current_section" == "$target_section" ]]; then
            # handle array assignment
            if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=\((.*)\)$ ]]; then
                key="${BASH_REMATCH[1]}"
                array_values="${BASH_REMATCH[2]}"
                # evaluate array values and convert them to an array
                eval "$key=($array_values)"

            # handle scalar assignment
            elif [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                # strip surrounding quotes if they exist
                value="${value%\"}"
                value="${value#\"}"

                # evaluate the value
                eval "$key=\"$value\""
            fi
        fi
    done < "$config_file"
} # parse_config_file
