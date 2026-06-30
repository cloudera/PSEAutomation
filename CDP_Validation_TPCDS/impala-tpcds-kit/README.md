# TPC-DS tools for Apache Impala

The official and latest TPC-DS tools and specification can be found at
[tpc.org](http://www.tpc.org/tpc_documents_current_versions/current_specifications.asp)

The query templates and sample queries provided in this repo are compliant with the standards set out by the TPC-DS benchmark specification and include only minor query modifications (MQMs) as set out by section 4.2.3 of the specification. The modification list can be found in [`query-templates/README.md`](query-templates/README.md).

If you use this repo for any results publication, please see [Fair Use of TPC Benchmarks](http://www.tpc.org/tpc_documents_current_versions/pdf/tpc_fair_use_quick_reference_v1.0.0.pdf).

## Citation:-
All the scripts are cloned from the repo https://github.com/cloudera/impala-tpcds-kit and modified as per our requirement. 

The automation part of running the tpc queries(Step 3) is cloned from the repo https://github.com/kcheeeung/hive-benchmark. 


## Step 0: Environment Setup

Install Java JDK and Maven if need be:

```
sudo yum -y install java-1.8.0-openjdk-devel maven
```

Install the necessary development tools:

```
sudo yum -y install git gcc make flex bison byacc curl unzip patch
```

## Step 1: Data Generation 

Data generation is done via a MapReduce wrapper around TPC-DS `dsdgen`. 

### MapReduce data generator: 
This simplifies creating TPC-DS datasets at large scales on a Hadoop cluster. To get set up, you need to run the following commands from the directory where you have cloned/copied the impala-tpcds-kit folder. 

```
cd impala-tpcds-kit/tpcds-gen

make
```

This will download the TPC-DS dsgen program, compile it, and use maven to build the MR app wrapped around it. 

### Data Generation: 
To generate the data use a variation of the following command to specify the target directory in HDFS (-d), the scale factor in GB (-s 10000, for 10TB), and the parallelism to use (-p 100). 

```
nohup time hadoop jar target/tpcds-gen-1.0-SNAPSHOT.jar -d <HDFS_DIR_for_data _gen> -p <parallelism> -s <scale-factor> > <log_file_name> &
```

Ex:- For 1T, 
```
nohup time hadoop jar target/tpcds-gen-1.0-SNAPSHOT.jar -d /tmp/Impala-TPC/1T -p 100 -s 1000 > 1T_data_gen_impala &
```
Please note that this test will create a destination directory and will generate the data files in that. For data generation, a MapReduce job will be started and you can check its progress from the Resource Manager Web UI as well. If the HDFS directory name you pass already exists, then it will fail. 

Also, please note that the above step will take a lot of time based on the underlying infrastructure and the scale-factor. That’s why, we have given a command which runs the script in background and you can keep checking the logs to see the progress. 

Use the below command to check the logs live. 
```
tail -f <log-file-name>
```

Once the job is complete, you can verify by checking the contents of the HDFS dir passed in the command. 

hadoop fs -ls <HDFS_DIR_for_data _gen>


## Step 2: Data Load

The below commands help in creating external tables stored as textfile, and another set of tables stored in parquet for running the tpc queries. These commands need two arguments to be passed, namely, the HDFS location where the data is generated(used in Data Generation step) and the scale factor. 

Create external text file tables:

```
impala-shell -V --var=scale=<scale_factor> --var=location=<HDFS_LOCATION> -f impala-external.sql
```

Create Parquet tables:

```
impala-shell -V --var=scale=<scale_factor> -f impala-parquet.sql
```

Load Parquet tables and compute stats:

```
impala-shell -V --var=scale=<scale_factor> -f impala-insert.sql
impala-shell -V --var=scale=<scale_factor> -f compute-stats.sql
```

## Step 3: Run Queries

Once all the tables are created, the next step is to run the TPC-DS queries and note down the timings each query takes. We have an automation that helps in running the set of queries and generates a .csv file with the query number and the time it took to run that 
query in Impala. 

Update the paths for the below variables in query_runner.sh script. 

```
QUERY_BASE_NAME
SETTINGS_PATH
FINAL_REPORT_LOCATION (This should be HDFS location)
```

Update the below details in util_internalRunQuery_impala.sh script. 

```
(Line 16) impala-shell command. Update the impala hostname, ssl details, truststore details and password. Change all those applicable.
```

Run the script 
```
nohup sh query_runner.sh > <log_file_name> &
```

If time permits, we recommend to run this script, query_runner, for two more times so that we can have the results for 3 iterations and that would help us in validation. If you are planning to do this, ensure you backup all the files generated as part of this test, as it removes the files before starting. 
