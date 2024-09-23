# TSMP2 workflow-engine

## Introduction

TSMP2 workflow engine for running simulations. The following examples and descriptions are based on a coupled climate simulation case over the EUR-11 domain, but the underlying idea applies to all types of simulations, such as LES, NWP, real and idealised cases. The workflow is applicable for any model combination within the TSMP2 framework realm.

## Setup the workflow

``` bash
cd $PROJECT_DIR
git clone --recurse-submodules https://github.com/HPSCTerrSys/TSMP2_workflow-engine
wfe_dir=realpath tsmp2_workflow-engine
```

## Building the model

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be either already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)) or compiled with the following steps.

0) change directory
```bash
cd ${wfe_dir}/src/TSMP2
```

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
vi control_tsmp2.sh
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
sh control_tsmp2.sh
```

## Contact
Stefan Poll (s.poll@fz-juelich.de)
