# ideal_fs-idealnwp_ICONv2.6.4-eCLM-ParFlowv3.12

## Introduction

This make use of the TSMP2 workflow engine for running simulations.

## Setup the workflow

``` bash
sim_id=ideal_fs-idealnwp_iconv2.6.4-eclm-parflowv3.12_wfe-case
cd $PROJECT_DIR
git clone --recurse-submodules https://github.com/HPSCTerrSys/simexp_$sim_id $sim_id
wfe_dir=realpath $sim_id
```

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)).

## Building the model

In case the model is already build, this step can be skipped by setting the `TSMP2_DIR` variable to the directory of TSMP2.

0) change directory
cd ${wfe_dir}/src/TSMP2

1) compile the code

```bash
# TSMP2
./build_tsmp2.sh --icon --eclm --parflow
```

## Run experiment

Create and softlink run-directory on SCRATCH
``` bash
export SCRATCH_DIR=/p/scratch/YOUR_PROJECT/$USER/$sim_id
mkdir -pv $SCRATCH_DIR
ln -s $SCRATCH_DIR/run run
```

Adapt ressources and time in the setup-script. 
``` bash
cd ctl
vi setup_simple.sh
```

Activate a compute project
```bash
# Replace PROJECTNAME with your compute project
jutil env activate -p PROJECTNAME

# Check if $BUDGET_ACCOUNTS was set.
echo $BUDGET_ACCOUNTS
```

Start simulation
``` bash
sh setup_simple.sh
```

## Contact
Stefan Poll (s.poll@fz-juelich.de)
