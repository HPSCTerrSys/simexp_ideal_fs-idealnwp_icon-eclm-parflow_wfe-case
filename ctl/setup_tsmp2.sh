#!/usr/bin/env bash
# Basic script to manage settings
# Stefan Poll (s.poll@fz-juelich.de)
set -e

###########################################
###
# Settings
###

# number of nodes per component
ico_node=1
clm_node=1
pfl_node=1

# user setting, leave empty for jsc machine defaults
npnode_u="" # number of cores per node
partition_u="" # compute partition
account_u=$BUDGET_ACCOUNTS # SET compute account. If not set, slts is taken
wallclock=00:10:00 #04:00:00 # needs to be format hh:mm:ss

MODEL_ID=ICON-eCLM #ICON-eCLM-ParFlow #ParFlow #ICON-eCLM #ICON-eCLM-ParFlow #ICON 
tsmp2_dir_u=$TSMP2_DIR
tsmp2_install_dir_u="" # leave empty to take default
tsmp2_env_u="" # leave empty to take default

EXP_ID="fs-idealnwp"

cpltsp_atmsfc=600 # coupling time step, atm-sfc, eCLM timestep
cpltsp_sfcss=600 # coupling time step, sfc-ss, ParFlow timestep
simlength="1 day"
startdate="2015-07-01T00:00Z" # ISO norm 8601

###########################################

###
# Start of script
###

modelid=$(echo ${MODEL_ID//"-"/} | tr '[:upper:]' '[:lower:]')

datep1=$(date -u -d -I "+${startdate} + ${simlength}")
simlensec=$(( $(date -u -d "${datep1}" +%s)-$(date -u -d "${startdate}" +%s) ))
simlenhr=$(($simlensec/3600 | bc -l))
dateymd=$(date -u -d "${startdate}" +%Y%m%d)
#datedir=$(date -u -d "${startdate}" +%Y%m%d%H)

# set path
ctl_dir=$(pwd)
run_dir=$(realpath ${ctl_dir}/../run/${modelid}_${dateymd}/)
#run_dir=$(realpath ${ctl_dir}/../run/${SYSTEMNAME}_${modelid}_${dateymd}/)
nml_dir=$(realpath ${ctl_dir}/namelist/)
geo_dir=$(realpath ${ctl_dir}/../geo/)
pre_dir=$(realpath ${ctl_dir}/../pre/)

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

###
# Import functions
###
source ${ctl_dir}/config_simulation.sh

###
# Start replacing variables
###

# configure TSMP2 run-directory
config_tsmp2_simulation

###
# Submit job
###

sbatch ${run_dir}/tsmp2.job.jsc

