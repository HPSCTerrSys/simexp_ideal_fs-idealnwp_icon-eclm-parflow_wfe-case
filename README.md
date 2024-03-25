# EUR-0275_ICONv2.6.4-eCLM-ParFlowv3.12

## Introdction

This is a simple (!) workflow engine for running TSMP2 simulations.

## Setup the workflow

``` bash
cd $PROJECT_DIR
git clone --recurse-submodules https://icg4geo.icg.kfa-juelich.de/Configurations/tsmp2/eur-0275_iconv2.6.4-eclm-parflowv3.12_testcase
```

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)). 

## Run case

The `TSMP2_DIR` variable needs to be set to the directory of TSMP2. 

Adapt ressources and time in the setup-script. 
``` bash
cd ctl
vi setup_simple.sh
```

Start simulation
``` bash
sh setup_simple.sh
```

## Contact
Stefan Poll (s.poll@fz-juelich.de)
