#!/usr/bin/env bash
# Control-script and starter for TSMP2 Workflow engine (TSMP2-WFE)
# for preprocessing, simulation, postprocessing, monitoring, cleaning/archiving
#
# Author(s): Stefan Poll (s.poll@fz-juelich.de)

# exit with error, export variables
set -ae

###########################################
###
# Settings
###

# main settings
MODEL_ID=ICON-eCLM-ParFlow #ParFlow #ICON-eCLM #ICON-eCLM-ParFlow #ICON
EXP_ID="eur-11u"
CASE_ID="" # identifier for cases

# main switches (PREprocessing, SIMulations, POSt-processing, VISualisation)
lpre=( false false false ) # config, run, cleanup
lsim=( true true true ) # config, run, cleanup
lpos=( false false false ) # config, run, cleanup
lvis=( false false false ) # config, run, cleanup

# time information
cpltsp_atmsfc=1800 # coupling time step, atm-sfc, eCLM timestep [sec]
cpltsp_sfcss=1800 # coupling time step, sfc-ss, ParFlow timestep [sec]
simlength="1 day" #"23 hours"
startdate="2017-07-01T00:00Z" # ISO norm 8601
numsimstep=1 # number of simulation steps, simulation period = numsimstep * simlength

# user setting, leave empty for jsc machine defaults
prevjobid="" # previous job-id, default leave empty
npnode_u="" # number of cores per node
partition_u="" # compute partition
account_u=$BUDGET_ACCOUNTS # SET compute account. If not set, slts is taken

# wallclock
pre_wallclock=00:05:00
sim_wallclock=00:10:00 # needs to be format hh:mm:ss
pos_wallclock=00:05:00
vis_wallclock=00:05:00

# file/directory pathes
tsmp2_dir_u=$TSMP2_DIR
tsmp2_install_dir_u="" # leave empty to take default
tsmp2_env_u="" # leave empty to take default

# number of nodes per component (<comp>_node will be set to zero, if not indicated in MODEL_ID)
ico_node=3
clm_node=1
pfl_node=2

###########################################

###
# Start of script
###

echo "#####"
echo "## Start TSMP WFE"
echo "#####"

# set modelid, caseid and expid
modelid=$(echo ${MODEL_ID//"-"/} | tr '[:upper:]' '[:lower:]')
if [ -n "${CASE_ID}" ]; then caseid+=${CASE_ID,,}"_"; fi
expid=${EXP_ID,,}

# set path (not run-dir)
ctl_dir=$(dirname $(realpath ${BASH_SOURCE:-$0}))
nml_dir=$(realpath ${ctl_dir}/../nml/)
geo_dir=$(realpath ${ctl_dir}/../dta/geo/)
frc_dir=$(realpath ${ctl_dir}/../dta/forcing/)

# select machine defaults, if not set by user
if ( [ -z $npnode_u ] | [ -z $partition_u ] ); then
echo "Take system default for npnode and partition. "
if [ ${SYSTEMNAME^^} == "JUWELS" ];then
npnode=48
partition=batch
elif [ ${SYSTEMNAME^^} == "JURECADC" ] || [ ${SYSTEMNAME^^} == "JUSUF" ];then
npnode=128
partition=dc-cpu
else
echo "Machine '$SYSTEMNAME' is not recognized. Valid input juwels/jurecadc/jusuf."
fi
else
echo "Take user setting for nonode $npnode and partition $partition."
npnode=$npnode_u
partition=$partition_u
fi

if [ -z $account_u ]; then
echo "WARNING: No account is set. Take slts!"
account=slts
else
account=$account_u
fi

if [ -z "$tsmp2_dir_u" ]; then
tsmp2_dir=$(realpath  ${ctl_dir}/../src/TSMP2)
echo "Take TSMP2 default dir at $tsmp2_dir"
else
tsmp2_dir=$tsmp2_dir_u
fi
if [ -z "$tsmp2_install_dir_u" ]; then
tsmp2_install_dir=${tsmp2_dir}/bin/${SYSTEMNAME^^}_${MODEL_ID}
echo "Take TSMP2 component binaries from default dir at $tsmp2_install_dir"
else
tsmp2_install_dir=$tsmp2_install_dir_u
fi
if [ -z "$tsmp2_env_u" ]; then
tsmp2_env=$tsmp2_install_dir/jsc.2023_Intel.sh
echo "Use enviromnent file $tsmp2_env"
else
tsmp2_env=$tsmp2_env_u
fi

# Import function
source ${ctl_dir}/utils_tsmp2.sh

# generic sbatch string
jobgenstring="--export=ALL \
	      --account=$account
              --partition=$partition"

###
# Loop over time period
###

icounter=0
while [ $icounter -lt $numsimstep ]
do

# set run path
sim_dir=$(realpath ${ctl_dir}/../run/sim_${caseid}${modelid}_${dateymd}/)
#sim_dir=$(realpath ${ctl_dir}/../run/${SYSTEMNAME}_${modelid}_${dateymd}/)
pre_dir=$(realpath ${ctl_dir}/../run/pre_${caseid}${modelid}_${dateymd}/)

# time information
datep1=$(date -u -d -I "+${startdate} + ${simlength}")
simlensec=$(( $(date -u -d "${datep1}" +%s)-$(date -u -d "${startdate}" +%s) ))
simlenhr=$(($simlensec/3600 | bc -l))
dateymd=$(date -u -d "${startdate}" +%Y%m%d)
dateshort=$(date -u -d "${startdate}" +%Y%m%d%H%M%S)

echo "==="
echo "Date: $dateshort"
echo "==="

#####
## Preprocessing
#####

# check if any is true
if [[ ${lpre[*]} =~ true ]]; then

jobprestring="${jobgenstring} \
              --job-name="${expid}_${caseid}pre_${dateshort}" \
              --time=${pre_wallclock}
              --output="${pre_dir}/%x_%j.out" \
              --error="${pre_dir}/%x_%j.err" \
              --nodes=1 \
              --ntasks=${npnode}"

# Submit to pre.job
sbatch ${jobprestring} ${ctl_dir}/pre_ctl/pre.job

fi # $lpre

######
## Simulations
######

# check if any is true
if [[ ${lsim[*]} =~ true ]]; then

# Calculate number of procs for TSMP2 simulation (utils)
sim_calc_numberofproc

#
jobsimstring="${jobgenstring} \
              --job-name="${expid}_${caseid}sim_${dateshort}" \
	      --time=${sim_wallclock}
              --output="${sim_dir}/%x_%j.out" \
              --error="${sim_dir}/%x_%j.err" \
	      --nodes=${tot_node} \
	      --ntasks=${tot_proc}"

# Submit to sim.job
# echo "sbatch ${jobsimstring} ${ctl_dir}/sim_ctl/sim.job"
sbatch ${jobsimstring} ${ctl_dir}/sim_ctl/sim.job

fi # $lsim

######
## Postprocessing
######

# check if any is true
if [[ ${lpos[*]} =~ true ]]; then

# Configure TSMP2 Postprocessing
jobposstring="${jobgenstring} \
              --job-name="${expid}_${caseid}pos_${dateshort}" \
              --time=${pos_wallclock}
              --output="${pos_dir}/%x_%j.out" \
              --error="${pos_dir}/%x_%j.err" \
              --nodes=1 \
              --ntasks=${npnode}"

# Submit to pos.job
sbatch ${jobposstring} ${ctl_dir}/pos_ctl/pos.job

fi # $lpos

###
# Loop increment
###

startdate=$(date -u -d "${startdate} +${simlength}" "+%Y-%m-%dT%H:%MZ")
icounter=$((icounter+1))
#(( icounter++ ))

done # icounter

exit 0
