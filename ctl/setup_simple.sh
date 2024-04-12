#!/usr/bin/env bash
# Basic script to manage settings
# Stefan Poll (s.poll@fz-juelich.de)
set -e

###########################################
###
# Settings
###

# number of nodes per component
ico_node=20
clm_node=5
pfl_node=4 #4

# user setting, leave empty for jsc machine defaults
npnode_u="" # number of cores per node
partition_u="" # compute partition
account_u="" # SET compute account, by default slts is taken
wallclock=00:10:00 #04:00:00 # needs to be format hh:mm:ss

MODEL_ID=ICON-eCLM #eCLM #ICON
if [ -n "$TSMP2_DIR" ]; then
tsmp2_dir=$TSMP2_DIR
else
tsmp2_dir=/p/project/cslts/$USER/TSMP2
fi
tsmp2_install_dir=${tsmp2_dir}/run/${SYSTEMNAME^^}_${MODEL_ID}
tsmp2_env=$tsmp2_dir/env/jsc.2022_Intel.sh

cpl_frq=1800
simlength="1 day"
startdate="2015-01-01T00:00Z" # ISO norm 8601

###########################################
###
# Start of script
###

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
echo "Take user setting for nonode and partition."
npnode=$npnode_u
partition=$partition_u
fi

if [ -z $account_u ]; then
echo "WARNING: No account is set. Take slts!"
account=slts
else
account=$account_u
fi

# calculate needed variables
ico_proc=$(($ico_node*$npnode))
clm_proc=$(($clm_node*$npnode))
pfl_proc=$(($pfl_node*$npnode))
pfl_procY=12
pfl_procX=$(($pfl_proc/$pfl_procY))

modelid=$(echo ${MODEL_ID//"-"/} | tr '[:upper:]' '[:lower:]')

datep1=$(date -u -d -I "+${startdate} + ${simlength}")
simlensec=$(( $(date -u -d "${datep1}" +%s)-$(date -u -d "${startdate}" +%s) ))
simlenhr=$(($simlensec/3600 | bc -l))
dateymd=$(date -u -d "${startdate}" +%Y%m%d)
#datedir=$(date -u -d "${startdate}" +%Y%m%d%H)

###
# Start replacing variables
###

####################
# General
####################

# set path
ctl_dir=$(pwd)
run_dir=$(realpath ${ctl_dir}/../run/${modelid}_${dateymd}/)
nml_dir=$(realpath ${ctl_dir}/namelist/)
geo_dir=$(realpath ${ctl_dir}/../geo/)
pre_dir=$(realpath ${ctl_dir}/../pre/)

# create and clean-up run-dir 
echo "rundir can be found at: "$run_dir
mkdir -pv $run_dir
#rm -f $run_dir/* 

# copy blueprints (changes need to be done in the "*sed*" files)
cp ${ctl_dir}/jobscripts/slm_multiprog_mapping_sed.conf ${run_dir}/slm_multiprog_mapping.conf
cp ${ctl_dir}/jobscripts/${modelid}.job.jsc_sed ${run_dir}/tsmp2.job.jsc

# slm_multiprog
if [[ "${modelid}" != *icon* ]]; then
   sed -i "/__icon_pe__/d" ${run_dir}/slm_multiprog_mapping.conf
   ico_node=0
   ico_proc=0
fi
if [[ "${modelid}" != *eclm* ]]; then
   sed -i "/__clm_pe__/d" ${run_dir}/slm_multiprog_mapping.conf
   clm_node=0
   clm_proc=0
fi
if [[ "${modelid}" != *parflow* ]]; then
   sed -i "/__pfl_pe__/d" ${run_dir}/slm_multiprog_mapping.conf
   pfl_node=0
   pfl_proc=0
fi
sed -i "s/__icon_pe__/$(($ico_proc-1))/" ${run_dir}/slm_multiprog_mapping.conf
sed -i "s/__clm_ps__/$(($ico_proc))/" ${run_dir}/slm_multiprog_mapping.conf
sed -i "s/__clm_pe__/$(($ico_proc+$clm_proc-1))/" ${run_dir}/slm_multiprog_mapping.conf
sed -i "s/__pfl_ps__/$(($ico_proc+$clm_proc))/" ${run_dir}/slm_multiprog_mapping.conf
sed -i "s/__pfl_pe__/$(($ico_proc+$clm_proc+$pfl_proc-1))/" ${run_dir}/slm_multiprog_mapping.conf

# jobscript
sed -i "s#__wallclock__#$wallclock#" ${run_dir}/tsmp2.job.jsc
sed -i "s#__loadenvs__#$tsmp2_env#" ${run_dir}/tsmp2.job.jsc
sed -i "s/__ntot_proc__/$(($ico_proc+$clm_proc+$pfl_proc))/" ${run_dir}/tsmp2.job.jsc
sed -i "s/__ntot_node__/$(($ico_node+$clm_node+$pfl_node))/" ${run_dir}/tsmp2.job.jsc
sed -i "s#__run_dir__#$run_dir#" ${run_dir}/tsmp2.job.jsc
sed -i "s/__partition__/$partition/" ${run_dir}/tsmp2.job.jsc
sed -i "s/__account__/$account/" ${run_dir}/tsmp2.job.jsc
sed -i "s/__npnode__/$npnode/" ${run_dir}/tsmp2.job.jsc
sed -i "s#__parflow_bin__#$tsmp2_install_dir#" ${run_dir}/tsmp2.job.jsc

# change to run directory
cd ${run_dir}

####################
# ICON
####################
if [[ "${modelid}" == *icon* ]]; then

# link executeable (will be replaced with copy in production)
  ln -sf $tsmp2_install_dir/bin/icon icon

# copy namelist
  cp ${nml_dir}/icon/NAMELIST_icon NAMELIST_icon
  cp ${nml_dir}/icon/icon_master.namelist icon_master.namelist
  cp ${nml_dir}/icon/dict.latbc dict.latbc

# ICON NML
  sed -i "s#__forcdir__#${pre_dir}/icon/$(date -u -d "${startdate}" +%Y_%m)#" NAMELIST_icon
  sed -i "s#__ecraddata_dir__#/p/scratch/cslts/poll1/ecraddata#" NAMELIST_icon # needs to be short path in ICON v2.6.4
  sed -i "s/__dateymd__/${dateymd}/" NAMELIST_icon
  sed -i "s/__outdatestart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outdateend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__simstart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist
  sed -i "s/__simend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist

# link needed files
  ln -sf ${geo_dir}/static/icon/EUR-R13B07_2473796_grid_inclbrz_v1.nc EUR-R13B07_2473796_grid_inclbrz_v1.nc
  ln -sf ${geo_dir}/static/icon/external_parameter_icon_EUR-R13B07_2473796_grid_inclbrz_v1.nc external_parameter_icon_EUR-R13B07_2473796_grid_inclbrz_v1.nc
  ln -sf ${geo_dir}/static/icon/bc_greenhouse_rcp45_1765-2500.nc bc_greenhouse_rcp45_1765-2500.nc

fi # if modelid == ICON

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

# 
  geo_dir_clm=${geo_dir}/static/eclm/
  clm_tsp=${cpl_frq}
# 
  fini_clm=${pre_dir}/eclm/CLM5EUR-0275_SP_ERA5_GLC2000_newmask_spinupv2.clm2.r.2015-01-01-00000.nc

# link executeable
  ln -sf $tsmp2_install_dir/bin/eclm.exe eclm

# calculation for automated adjustment of clm forcing
  forcedate=$(date '+%s' -d "${datep1} + 1 month - 1 day")
  ldate="${startdate}"
  forcdatelist=""
  while [[ $(date +%s -d $ldate) -le $forcedate ]]; do
    forcdatelist+=$(echo "${ldate%-*}.nc\n")
    ldate=$(date '+%Y-%m-%d' -d "$ldate +1 month")
  done
  forcdatelist=${forcdatelist::-2} # delete last new line command

# copy namelist
  cp ${nml_dir}/eclm/drv_in drv_in
  cp ${nml_dir}/eclm/lnd_in lnd_in
  cp ${nml_dir}/eclm/datm_in datm_in
  cp ${nml_dir}/eclm/drv_flds_in drv_flds_in
  cp ${nml_dir}/eclm/mosart_in mosart_in
  cp ${nml_dir}/eclm/datm.streams.txt* .
  cp ${nml_dir}/eclm/cime/* .

# CLM NML
  sed -i "s/__nclm_proc__/$(($clm_proc))/" drv_in
  sed -i "s/__clm_tsp__/$clm_tsp/" drv_in
  sed -i "s/__clm_tsp2__/$(($clm_tsp*3 | bc -l))/" drv_in
  sed -i "s/__simstart__/$(date -u -d "${startdate}" +%Y%m%d)/" drv_in
  sed -i "s/__simend__/$(date -u -d "${datep1}" +%Y%m%d)/" drv_in
  sed -i "s/__simrestart__/$(date -u -d "${datep1}" +%Y%m%d)/" drv_in
  sed -i "s/__clm_tsp__/$clm_tsp/" lnd_in
  sed -i "s#__fini_clm__#$fini_clm#" lnd_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" lnd_in
  if [[ "${modelid}" != *parflow* ]]; then
    sed -i "s/__swmm__/1/" lnd_in # soilwater_movement_method
#    sed -i "s/__clmoutvar__/'TLAI', 'FIRA', 'FIRE', 'ALBD', 'ALBI', 'TSA', 'TV', 'TG', 'TSKIN', 'TSOI','FSH','EFLX_LH_TOT'/" lnd_in
    sed -i "s/__clmoutvar__/'TWS','H2OSOI','QFLX_EVAP_TOT','TG','TSOI','FSH','FSR'/" lnd_in
  else
    sed -i "s/__swmm__/4/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/'PFL_PSI', 'PFL_PSI_GRC', 'PFL_SOILLIQ', 'PFL_SOILLIQ_GRC', 'RAIN', 'SNOW', 'SOILPSI', 'SMP', 'QPARFLOW', 'FH2OSFC', 'FH2OSFC_NOSNOW', 'FRAC_ICEOLD', 'FSAT', 'H2OCAN', 'H2OSFC', 'H2OSNO', 'H2OSNO_ICE', 'H2OSOI', 'LIQCAN', 'LIQUID_WATER_TEMP1', 'OFFSET_SWI', 'ONSET_SWI', 'QH2OSFC', 'QH2OSFC_TO_ICE', 'QROOTSINK', 'QTOPSOIL', 'SNOLIQFL', 'SNOWLIQ', 'SNOWLIQ_ICE', 'SNOW_SINKS', 'SNOW_SOURCES', 'SNO_BW', 'SNO_BW_ICE', 'SNO_LIQH2O', 'SOILLIQ', 'SOILPSI', 'SOILWATER_10CM', 'TH2OSFC', 'TOTSOILLIQ', 'TWS', 'VEGWP', 'VOLR', 'VOLRMCH', 'WF', 'ZWT', 'ZWT_CH4_UNSAT', 'ZWT_PERCH', 'watfc', 'watsat', 'QINFL', 'Qstor', 'QOVER', 'QRUNOFF', 'EFF_POROSITY', 'TSOI', 'TSKIN', 'QDRAI'/" lnd_in
  fi
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm_in
  sed -i "s/__simystart__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s/__simyend__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" drv_flds_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" mosart_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm.streams.txt*
  # forcing
  sed -i "s#__forcdir__#${pre_dir}/eclm/forcing/#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__forclist__#${forcdatelist}#" datm.streams.txt.CLMCRUNCEPv7.*
fi # if modelid == CLM

####################
# PFL
####################
if [[ "${modelid}" == *parflow* ]]; then

# link executeable
  ln -sf $tsmp2_install_dir/bin/parflow parflow

# copy namelist
  cp ${nml_dir}/parflow/ascii2pfb_slopes.tcl ascii2pfb_slopes.tcl
  cp ${nml_dir}/parflow/ascii2pfb_SoilInd.tcl ascii2pfb_SoilInd.tcl
  cp ${nml_dir}/parflow/coup_oas.tcl coup_oas.tcl

# PFL NML
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" coup_oas.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" coup_oas.tcl
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_slopes.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_slopes.tcl
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_SoilInd.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_SoilInd.tcl

fi # if modelid == parflow

####################
# OASIS
####################

if [[ "${MODEL_ID}" == *-* ]]; then

# copy namelist
  cp ${nml_dir}/oasis/namcouple_${modelid} namcouple

# OAS NML
  sed -i "s/__cplfrq__/$cpl_frq/" namcouple
  sed -i "s/__simlen__/$simlensec/" namcouple

# copy remap-files
  cp ${geo_dir}/static/oasis/masks.nc .
#  cp ${geo_dir}/static/oasis/grids.nc .
  if [[ "${modelid}" == *icon* ]]; then
    cp ${geo_dir}/static/oasis/rmp* .
  fi

fi # if modelid == oasis

echo "Configured case."

###########################################
###
# Submit job
###

#sbatch tsmp2.job.jsc

#echo "Submitted job"
