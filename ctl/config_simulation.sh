#!/usr/bin/env bash
#
# function to configure tsmp2 simulations

config_tsmp2_simulation(){

echo "###"
echo "# Configure Simulation"
echo "###"

# calculate needed variables
ico_proc=$(($ico_node*$npnode))
clm_proc=$(($clm_node*$npnode))
pfl_proc_tmp=$(($pfl_node*$npnode))
pfl_proc_sqrt=$(echo "sqrt($pfl_proc_tmp)" | bc -l)
pfl_procY=$((${pfl_proc_sqrt%.*} + (2 - ${pfl_proc_sqrt%.*} % 2))) # go to next num of 2
pfl_procX=$(($pfl_proc_tmp/$pfl_procY))
pfl_proc=$(($pfl_procY*$pfl_procX))
unset pfl_proc_tmp pfl_proc_sqrt

###
# Start replacing variables
###

####################
# General
####################

# create and clean-up run-dir 
echo "rundir: "$run_dir
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
#  ln -sf $tsmp2_install_dir/bin/icon icon
  cp $tsmp2_install_dir/bin/icon icon

# copy namelist
  cp ${nml_dir}/icon/NAMELIST_icon NAMELIST_icon
  cp ${nml_dir}/icon/icon_master.namelist icon_master.namelist

# ICON NML
  sed -i "s#__ecraddata_dir__#ecraddata#" NAMELIST_icon # needs to be short path in ICON v2.6.4
  sed -i "s/__dateymd__/${dateymd}/" NAMELIST_icon
  sed -i "s/__outdatestart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outdateend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outname__/out_icon_${EXP_ID}/" NAMELIST_icon
  sed -i "s/__simstart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist
  sed -i "s/__simend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist

# link needed files
  ln -sf ${geo_dir}/icon/static/torus_grid_x70_y70_e2000m.nc
  ln -sf ${geo_dir}/icon/static/ecraddata

fi # if modelid == ICON

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

# 
  geo_dir_clm=${geo_dir}/eclm/static
  clm_tsp=${cpltsp_atmsfc}
  clmoutfrq=-1
#
  domainfile_clm=domain_ICON_torus_70x70_e2000_240516.nc
  surffile_clm=surfdata_${EXP_ID}_${CASE_ID:0:11}.nc
  fini_clm=""

# link executeable
#  ln -sf $tsmp2_install_dir/bin/eclm.exe eclm
  cp $tsmp2_install_dir/bin/eclm.exe eclm

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
  sed -i "s/__clm_casename__/eCLM_${EXP_ID}/" drv_in
  sed -i "s/__clm_tsp__/$clm_tsp/" lnd_in
  sed -i "s/\( hist_nhtfrq =\).*/\1 $clmoutfrq/" lnd_in
  sed -i "s#__fini_clm__#$fini_clm#" lnd_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" lnd_in
  sed -i "s#__domainfile_clm__#$domainfile_clm#" lnd_in
  sed -i "s#__surffile_clm__#$surffile_clm#" lnd_in
  if [[ "${modelid}" != *parflow* ]]; then
    sed -i "s/__swmm__/1/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/'TWS','H2OSOI','TSOI','TG','EFLX_LH_TOT','FSH','FSA','FSR','FIRA','Rnet','EFLX_SOIL_GRND'/" lnd_in
  else
    sed -i "s/__swmm__/4/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/'TWS','H2OSOI','TSOI','TG','EFLX_LH_TOT','FSH','FSA','FSR','FIRA','Rnet','EFLX_SOIL_GRND'/" lnd_in
#    sed -i "s/__clmoutvar__/'TWS','H2OSOI','QFLX_EVAP_TOT','TG','TSOI','FSH','FSR'/" lnd_in
#    sed -i "s/__clmoutvar__/'PFL_PSI', 'PFL_PSI_GRC', 'PFL_SOILLIQ', 'PFL_SOILLIQ_GRC', 'RAIN', 'SNOW', 'SOILPSI', 'SMP', 'QPARFLOW', 'FH2OSFC', 'FH2OSFC_NOSNOW', 'FRAC_ICEOLD', 'FSAT', 'H2OCAN', 'H2OSFC', 'H2OSNO', 'H2OSNO_ICE', 'H2OSOI', 'LIQCAN', 'LIQUID_WATER_TEMP1', 'OFFSET_SWI', 'ONSET_SWI', 'QH2OSFC', 'QH2OSFC_TO_ICE', 'QROOTSINK', 'QTOPSOIL', 'SNOLIQFL', 'SNOWLIQ', 'SNOWLIQ_ICE', 'SNOW_SINKS', 'SNOW_SOURCES', 'SNO_BW', 'SNO_BW_ICE', 'SNO_LIQH2O', 'SOILLIQ', 'SOILPSI', 'SOILWATER_10CM', 'TH2OSFC', 'TOTSOILLIQ', 'TWS', 'VEGWP', 'VOLR', 'VOLRMCH', 'WF', 'ZWT', 'ZWT_CH4_UNSAT', 'ZWT_PERCH', 'watfc', 'watsat', 'QINFL', 'Qstor', 'QOVER', 'QRUNOFF', 'EFF_POROSITY', 'TSOI', 'TSKIN', 'QDRAI'/" lnd_in
  fi
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm_in
  sed -i "s/__simystart__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s/__simyend__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s#__domainfile_clm__#$domainfile_clm#" datm_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" drv_flds_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" mosart_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm.streams.txt*
  sed -i "s#topodata_0.9x1.25_USGS_070110_stream_c151201.nc#topodata_0.9x1.25_zeroed.nc#" datm.streams.txt.topo.observed
  # forcing
  sed -i "s#__forcdir__#${geo_dir}/eclm/forcing/#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__forclist__#${forcdatelist}#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__domainfile_clm__#$domainfile_clm#" datm.streams.txt.CLMCRUNCEPv7.*
fi # if modelid == CLM

####################
# PFL
####################
if [[ "${modelid}" == *parflow* ]]; then

# link executeable
#  ln -sf $tsmp2_install_dir/bin/parflow parflow
  cp $tsmp2_install_dir/bin/parflow parflow

#  
  parflow_tsp=$(echo "$cpltsp_sfcss / 3600" | bc -l)
  parflow_base=0.0025
#  parflow_inifile=${pre_dir}/parflow/ini/rur_ic_press.pfb
  parflow_inifile=${geo_dir}/parflow/init/rur_ic_press_${CASE_ID:6:5}_${CASE_ID:12:4}.pfb

# copy namelist
#  cp ${nml_dir}/parflow/ascii2pfb_slopes.tcl ascii2pfb_slopes.tcl
#  cp ${nml_dir}/parflow/ascii2pfb_SoilInd.tcl ascii2pfb_SoilInd.tcl
  cp ${nml_dir}/parflow/coup_oas.tcl coup_oas.tcl
  cp ${parflow_inifile}  $(basename "$parflow_inifile")

# PFL NML
#  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_slopes.tcl
#  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_slopes.tcl
#  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_SoilInd.tcl
#  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_SoilInd.tcl
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" coup_oas.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" coup_oas.tcl
  sed -i "s/__ngpflx_bldsva__/70/" coup_oas.tcl
  sed -i "s/__ngpfly_bldsva__/70/" coup_oas.tcl
  sed -i "s/__base_pfl__/$parflow_base/" coup_oas.tcl
  sed -i "s/__start_cnt_pfl__/0/" coup_oas.tcl
  sed -i "s/__stop_pfl_bldsva__/$(echo "${simlenhr} + ${parflow_base}" | bc -l)/" coup_oas.tcl
  sed -i "s/__dt_pfl_bldsva__/$parflow_tsp/" coup_oas.tcl
  sed -i "s/__dump_pfl_interval__/1.0/" coup_oas.tcl
  sed -i "s/__pfl_casename__/$EXP_ID/" coup_oas.tcl
  sed -i "s#__inifile__#$(basename "$parflow_inifile")#" coup_oas.tcl

  sed -i "s/__pfl_expid__/$EXP_ID/" slm_multiprog_mapping.conf

# PFL NML change surface characteristics based on $CASE_ID
  # check sID
  if [ "${CASE_ID:9:2}" = "02" ];then
     sed -i "s/\( Geom.domain.Porosity.Value\).*/\1 0.389/" coup_oas.tcl
     sed -i "s/\( Geom.domain.RelPerm.Alpha\).*/\1 2.69/" coup_oas.tcl
     sed -i "s/\( Geom.domain.RelPerm.N\).*/\1 1.41/" coup_oas.tcl
     sed -i "s/\( Geom.domain.Saturation.Alpha\).*/\1 2.69/" coup_oas.tcl
     sed -i "s/\( Geom.domain.Saturation.N\).*/\1 1.41/" coup_oas.tcl
     sed -i "s/\( Geom.domain.Saturation.Sres\).*/\1 0.08/" coup_oas.tcl
  elif [ "${CASE_ID:9:2}" = "00" ];then
     sed -i "s/\( Geom.domain.Porosity.Value\).*/\1 0.441/" coup_oas.tcl
     sed -i "s/\( Geom.domain.RelPerm.Alpha\).*/\1 1.122/" coup_oas.tcl
     sed -i "s/\( Geom.domain.RelPerm.N\).*/\1 1.5488/" coup_oas.tcl
     sed -i "s/\( Geom.domain.Saturation.Alpha\).*/\1 1.122/" coup_oas.tcl
     sed -i "s/\( Geom.domain.Saturation.N\).*/\1 1.5488/" coup_oas.tcl
     sed -i "s/\( Geom.domain.Saturation.Sres\).*/\1 0.21/" coup_oas.tcl
  else
     echo "WARNING: No valid sID is chosen! Take sID02"
  fi

fi # if modelid == parflow

####################
# OASIS
####################

if [[ "${MODEL_ID}" == *-* ]]; then

# copy namelist
  cp ${nml_dir}/oasis/namcouple_${modelid} namcouple

# OAS NML
  sed -i "s/__cpltsp_as__/$cpltsp_atmsfc/" namcouple
  sed -i "s/__cpltsp_ss__/$cpltsp_sfcss/" namcouple
  sed -i "s/__simlen__/$(( $simlensec + $cpltsp_atmsfc ))/" namcouple
  sed -i "s/__icongp__/9800/" namcouple
  sed -i "s/__eclmgpx__/9800/" namcouple
  sed -i "s/__eclmgpy__/1/" namcouple
  sed -i "s/__parflowgpx__/70/" namcouple
  sed -i "s/__parflowgpy__/70/" namcouple

# copy remap-files
  cp ${geo_dir}/oasis/static/masks.nc .
#  cp ${geo_dir}/static/oasis/grids.nc .
  if [[ "${modelid}" == *parflow* ]]; then
    cp ${geo_dir}/oasis/static/rmp* .
  fi

fi # if modelid == oasis

echo "Configuration:"
echo "MODEL_ID: "$MODEL_ID
echo "CASE_ID: "$CASE_ID


###########################################

###
# Submit job
###

#sbatch tsmp2.job.jsc

#echo "Submitted job"

}
