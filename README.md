# EUR-0275_ICONv2.6.4-eCLM-ParFlowv3.12

## Introduction

This is a simple (!) workflow engine for running TSMP2 simulations.

## Setup the workflow

``` bash
cd $PROJECT_DIR
git clone --recurse-submodules https://icg4geo.icg.kfa-juelich.de/Configurations/tsmp2/eur-0275_iconv2.6.4-eclm-parflowv3.12_wfe-case
wfe_dir=`realpath eur-0275_iconv2.6.4-eclm-parflowv3.12_wfe-case`
```

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)).

** DETECT - users **
Please copy the git repository of the static fields from `/p/largedata2/detectdata/CentralDB/projects/z04/static_fields/TSMP_EUR-0275` and checkout the hash of the submodule. If the hash is not available, please contact `s.poll@fz-juelich.de`.

## Building the model

In case the model is already build, this step can be skipped by setting the `TSMP2_DIR` variable to the directory of TSMP2.

0) change directory
cd ${wfe_dir}/src

1) Download the code

```bash
# TSMP2
git clone -b frontend_prototype https://github.com/HPSCTerrSys/TSMP2.git
export TSMP2_DIR=$(realpath TSMP2)
cd $TSMP2_DIR

## NOTE: Download only the component models that you need! ##

# OASIS3-MCT
git clone https://icg4geo.icg.kfa-juelich.de/ExternalReposPublic/oasis3-mct
OASIS_SRC=`realpath oasis3-mct`

# eCLM
git clone https://github.com/HPSCTerrSys/eCLM.git
eCLM_SRC=`realpath eCLM`

# ICON
git clone https://icg4geo.icg.kfa-juelich.de/spoll/icon2.6.4_oascoup.git
ICON_SRC=`realpath icon2.6.4_oascoup`

# ParFlow
git clone -b v3.12.0 https://github.com/parflow/parflow.git
PARFLOW_SRC=`realpath parflow`
```

2. Save paths to tsmp2 path and components in `TSMP2_PATHS`.

```bash
TSMP2_ENV=${TSMP2_DIR}/env/jsc.2022_Intel.sh
```

```bash
export TSMP2_PATHS=${TSMP2_DIR}/tsmp2_paths.env
tee ${TSMP2_PATHS} <<EOF
TSMP2_DIR=${TSMP2_DIR}
TSMP2_ENV=${TSMP2_ENV}
OASIS_SRC=${OASIS_SRC}
eCLM_SRC=${eCLM_SRC}
ICON_SRC=${ICON_SRC}
PARFLOW_SRC=${PARFLOW_SRC}
EOF
```

3. Install model component

```bash
# Name of the coupled model (e.g. ICON-ECLM, ICON-eCLM-ParFlow)
export MODEL_ID="ICON-eCLM-ParFlow"
```

Compile the code
```bash
./${TSMP2_DIR}/build_tsmp2.sh
```

## Run experiment

Create and softlink run-directory on SCRATCH
``` bash
export SCRATCH_DIR=/p/scratch/YOUR_PROJECT/$USER/eur-0275_iconv2.6.4-eclm-parflowv3.12_wfe-case
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

### Create own preprocessed data
For pre-processing ERA5 data for ICON use the following repository and make the preprocessed data available in `pre/icon/$YY_$MM`.
``` bash
https://gitlab.jsc.fz-juelich.de/detect/detect_z03_z04/software_tools/prepro_era5-to-icon
```

## Contact
Stefan Poll (s.poll@fz-juelich.de)
