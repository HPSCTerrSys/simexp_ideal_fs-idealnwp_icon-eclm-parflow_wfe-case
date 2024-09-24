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
