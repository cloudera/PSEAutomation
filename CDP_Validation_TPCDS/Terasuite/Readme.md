## Run Terasuite for a specific data volume

The parameters need to be updated according to the data volume of your choice.

For 1T data, the parameters need to be updated as below. 

_parameters.sh_
```
#!/bin/bash
REPLICATION=3
BLOCK_SIZE=134217728
MAP_CPU=
REDUCE_CPU=
MAP_MEMORY=2048
REDUCE_MEMORY=2048
NUM_MAPPERS=Total number of vcores - 20
NUM_REDUCERS=No. of datanodes or nodemanagers
#NUM_MAPPERS=32
#NUM_REDUCERS=16
DATA_VOL=100000000     #10G
#DATA_VOL=1000000000    #100G
#DATA_VOL=2000000000    #200G
#DATA_VOL=5000000000    #500G
#DATA_VOL=10000000000   #1T
OUTPUT_DIR_PREFIX=10G
S3A_PREFIX=
#S3A_PREFIX=s3a://cldr-ecs-obs
```

### Parameter details: 
* REPLICATION:The recommended value is 3. You can run with 1,2 as well based on your use case. Replication is set to 3 by default. 
* BLOCK_SIZE: The recommended value is 134217728, which is 128MB. If you would like to run with a different block size, you can choose from the following standard values. 
    268435456 (256 MB)
    536870912 (512 MB)
    1073741824 (1024 MB)
  Block size is set to 128 MB (MiB). Memory for map and reduce tasks is set to 2G. At any phase of the job run, if you encounter any issue with map memory, feel free to increase this to higher value. 
* Number of mappers is, as a thumb rule, set to 20 vcores less than the total number of vcores available in the cluster. The remaining 20 vcores can also be used, however, they have been kept idle as a buffer. 
* Number of reducers is set to the number of datanodes or nodemanagers. This is to ensure that the reduce phase gets distributed across all the nodemanagers.
* MAP_MEMORY,REDUCE_MEMORY: These can be set to 2048 (2G) to start with. If your use case requires it to perform with higher memory, you can run it with increased value as well, from the following standard values. 
    4096 (4G)
    6144 (6G)
    8192 (8G)
* NUM_MAPPERS: Number of mappers is, as a thumb rule, set to 20 vcores less than the total number of vcores available in the cluster. The remaining 20 vcores can also be used, however, they have been kept idle as a buffer.  
* NUM_REDUCERS: Number of reducers is set to the number of datanodes(DN) or nodemanagers(NM). This is to ensure that the reduce phase gets distributed across all the nodemanagers. If you want to increase this, please make sure that it is a multiple of total number of DN or NM. 
* DATA_VOL: This is the value in bytes to be passed as the parameter and the Teragen script will generate 100*DATA_VOL bytes of data. 
* OUTPUT_DIR_SUFFIX: This is the value indicating how much data is being generated/sorted/validated. This will depend on the value you choose for DATA_VOL. Refer to the below table for the sample values for both DATA_VOL and OUTPUT_DIR_SUFFIX. 

Data volume  | DATA_VOL        |  OUTPUT_DIR_SUFFIX
------------ | ---------       |  ------------------
10G          | 100000000       |   10G
20G          | 200000000       |   20G
50G          | 500000000       |   50G
100G         | 1000000000      |   100G
200G         | 2000000000      |   200G
500G         | 5000000000      |   500G
1T           | 10000000000     |   1T
2T           | 20000000000     |   2T
5T           | 50000000000     |   5T
10T          | 100000000000    |   10T

### Execution Steps:

* In the location where the scripts have been copied, run the below command to add execute permission and trigger the test. This ensures that the job will be running in the background and you can check the log at any time. 

```
chmod +x *.sh

nohup sh terasuite.sh > terasuite_<OUTPUT_DIR_SUFFIX>_Log &
```

* To keep checking the logs, you can run the below command. 
```
tail -f terasuite_<OUTPUT_DIR_SUFFIX>_Log
```

* Additionally, you can track the progress from Resource Manager Web UI as well. 

* This script runs all three Teragen. Terasort, and Teravalidate jobs and if all the jobs are run successfully, then you will see the message TERASUITE TEST RAN SUCCESSFULLY at the end of execution.

* If there is any error during the execution, it could be due to multiple factors. 
    * Missing value in the parameter. 
    * Unaccepted value entered in the parameters file. 
    * Running out of memory, in which case, try to increase the Mapper and Reducer memory in the parameters file and rerun to see if the job completes. 
    * If you still are unable to proceed, please reach out to the Cloudera POC and they will be able to help you out.

### *Authors:*

* Kuldeep Sahu 
* Yash Gulati
