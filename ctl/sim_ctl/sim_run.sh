#!/usr/bin/env bash

sim_run(){

#LOADENVS=__loadenvs__
#CASE_DIR=__run_dir__
#export PARFLOW_DIR=__parflow_bin__

LOADENVS=${tsmp2_env}
CASE_DIR=${run_dir}


if [[ ! -f $LOADENVS || -z "$LOADENVS" ]]; then
  echo "ERROR: Loadenvs script '$LOADENVS' does not exist."
  exit 1
fi

cd $CASE_DIR
source $LOADENVS

if [[ "${modelid}" == *clm* ]]; then

# Set PIO log files
if [[ -z $SLURM_JOB_ID || "$SLURM_JOB_ID" == " " ]]; then
  LOGID=$(date +%Y-%m-%d_%H.%M.%S)
else
  LOGID=$SLURM_JOB_ID
fi
mkdir -p logs timing/checkpoints
LOGDIR=$(realpath logs)
comps=(atm cpl esp glc ice lnd ocn rof wav)
for comp in ${comps[*]}; do
  LOGFILE="$LOGID.comp_${comp}.log"
  sed -i "s#diro.*#diro = \"$LOGDIR\"#" ${comp}_modelio.nml
  sed -i "s#logfile.*#logfile = \"$LOGFILE\"#" ${comp}_modelio.nml
done

fi # eclm

if [[ "${modelid}" == *parflow* ]]; then

export PARFLOW_DIR=${tsmp2_install_dir}

# ParFlow config
#tclsh ascii2pfb_slopes.tcl
#tclsh ascii2pfb_SoilInd.tcl
tclsh coup_oas.tcl

fi # parflow

# Run model
TIME_START=$(date +%s)
echo ">>> TSMP2 started at $(date +%H:%M:%S)"
srun --multi-prog slm_multiprog_mapping.conf
TIME_END=$(date +%s)
echo ">>> TSMP2 finished at $(date +%H:%M:%S)"
echo ">>> TSMP2 runtime: $(date -u -d "0 $TIME_END sec - $TIME_START sec" +"%H:%M:%S")"

} # sim_run
