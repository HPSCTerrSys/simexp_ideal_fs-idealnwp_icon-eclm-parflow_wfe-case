# EUR-0275_ICONv2.6.4-eCLM-ParFlowv3.12

## Introdction

This is a simple (!) workflow engine for running TSMP2 simulations.

## Setup the workflow

``` bash
cd $PROJECT_DIR
git clone --recurse-submodules https://icg4geo.icg.kfa-juelich.de/Configurations/tsmp2/eur-0275_iconv2.6.4-eclm-parflowv3.12_wfe-case
```

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)). 

## Run case

The `TSMP2_DIR` variable needs to be set to the directory of TSMP2. 

Create and link run-directory on SCRATCH 
``` bash
mkdir -pv /p/scratch/YOUR_PROJECT/$USER/eur-0275_iconv2.6.4-eclm-parflowv3.12_wfe-case/run
ln -s /p/scratch/YOUR_PROJECT/$USER/eur-0275_iconv2.6.4-eclm-parflowv3.12_wfe-case/run run
```

Adapt ressources and time in the setup-script. 
``` bash
cd ctl
vi setup_simple.sh
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
