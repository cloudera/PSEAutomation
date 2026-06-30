hive-testbench (TPCDS)
==============

A testbench for experimenting with Apache Hive at any data scale.

Overview
========

The hive-testbench is a data generator and set of queries that lets you experiment with Apache Hive at scale. The testbench allows you to experience base Hive performance on large datasets, and gives an easy way to see the impact of Hive tuning parameters and advanced settings.

Prerequisites
=============

You will need:
* CDP 7.1.4+ or later cluster or Sandbox. (7.1.4 required to support legacy CREATE for EXTERNAL tables)
* Apache Hive.
* Between 15 minutes and 2 days to generate data (depending on the Scale Factor you choose and available hardware).
* If you plan to generate 1TB or more of data, using Apache Hive 13+ to generate the data is STRONGLY suggested.

Install and Setup
=================

All of these steps should be carried out on your Hadoop cluster.

- Step 1: Prepare your environment.

  In addition to Hadoop and Hive, before you begin ensure ```gcc``` is installed and available on your system path. If you system does not have it, install it using yum or apt-get.

- Step 2: Decide which test suite(s) you want to use.

  hive-testbench comes with data generators and sample queries based on both the TPC-DS and TPC-H benchmarks. You can choose to use either or both of these benchmarks for experiementation. More information about these benchmarks can be found at the Transaction Processing Council homepage.

- Step 3: Compile and package the appropriate data generator.

  For TPC-DS, ```./tpcds-build.sh``` downloads, compiles and packages the TPC-DS data generator.
  For TPC-H, ```./tpch-build.sh``` downloads, compiles and packages the TPC-H data generator.

- Step 4: Decide how much data you want to generate OR [Performance Testing](#performance-testing)

  You need to decide on a "Scale Factor" which represents how much data you will generate. Scale Factor roughly translates to gigabytes, so a Scale Factor of 100 is about 100 gigabytes and one terabyte is Scale Factor 1000. Decide how much data you want and keep it in mind for the next step. If you have a cluster of 4-10 nodes or just want to experiment at a smaller scale, scale 1000 (1 TB) of data is a good starting point. If you have a large cluster, you may want to choose Scale 10000 (10 TB) or more. The notion of scale factor is similar between TPC-DS and TPC-H.

  If you want to generate a large amount of data, you should use Hive 13 or later. Hive 13 introduced an optimization that allows far more scalable data partitioning. Hive 12 and lower will likely crash if you generate more than a few hundred GB of data and tuning around the problem is difficult. You can generate text or RCFile data in Hive 13 and use it in multiple versions of Hive.

- Step 5: Generate and load the data.

  The scripts ```tpcds-setup.sh``` generate and load data for TPC-DS, respectively. General usage is ```tpcds-setup.sh --scale <scale_factor> [--dir <directory>] [--no-part] [--external] [--format <format>]```

  `--scale` The size in GB of the text data used to build the tpcds dataset, required.
  `--dir` The directory on hdfs where the data is written, optional.  (default: /tmp/tpcds-generate-<scale>)
  `--no-part` Generate the final tables with no partitions, optional.  When not set, datasets with partitions are created.
  `--external` Generate the final tables as external, optional.  When not set, managed tables are created.
  `--format` Generate the final tables in this hive format (default: orc)

  Some examples:

  Build 1 TB of TPC-DS data: ```./tpcds-setup.sh --scale 1000``` will build a 1Tb dataset that's transformed into 'managed', 'orc', and 'partitioned' tables.

  Build 100 TB of TPC-DS data: ```./tpcds-setup.sh --scale 100000``` will build a 100Tb dataset that's transformed into 'managed', 'orc', and 'partitioned' tables.

  Build 30 TB of RCFile formatted TPC-DS data: ```./tpcds-setup --scale 30000 --format rcfile``` will build a 30Tb dataset that's transformed into 'managed', 'rcfile', and 'partitioned' tables.

- Step 6: Run queries.

  More than 99 sample TPC-DS queries are included for you to try. You can use ```hive```, ```beeline``` or the SQL tool of your choice. The testbench also includes a set of suggested settings.

  This example assumes you have generated 1 TB of TPC-DS data during Step 5:

  	```
  	cd sample-queries-tpcds
  	hive -i testbench.settings
  	hive> use tpcds_bin_partitioned_orc_1000;
  	hive> !run query55.sql;
  	```
  The final databases are named based on the input parameters.  Here are a few examples:
  ```
  tpcds_bin_partitioned_managed_orc_100
  tpcds_bin_partitioned_external_orc_100
  tpcds_bin_not_partitioned_managed_orc_100
  tpcds_bin_not_partitioned_external_orc_100
  ```

  You can use `./tpcds-setup-all.sh` to buildout these four databases based on 'orc', 'managed vs. external', and 'partitioned vs. not partitioned'.
 
  Note that the database is name is postfixed with the Data Scale chosen in step 3. At Data Scale 10000, your database will be named tpcds_bin_<partitioned_managed_orc>_10000. You can always ```show databases``` to get a list of available databases.

Performance Testing
=================

After Step 3 in [Install and Setup](#install-and-setup) you can choose to buildout a series for 4 databases (dimensions) that you can run performance tests against.  This will help build an understanding of what design and access patterns work well together.  Warning: There is never an 'absolute' best dimension to choose.  You'll see.. ;)

The [./tpcds-setup-all.sh](./tpcds-setup-all.sh) script will generate the `--scale` datasets you choose and build 4 test databases off that generated data.  They will be:

- Managed, Partitioned, Orc
- Managed, Not Partitioned, Orc
- External, Partitioned, Orc
- External, Not Partitioned, Orc

Once built, review and run the tpcds [time.sh](./sample-queries-tpcds/time.sh) query to iterate through all the tpcds queries on the `--db` you choose.

OR

Run the [time_again.sh](./sample-queries-tpcds/time_again.sh) script to 'iterate' over ALL 4 dimensions `--iterations` times.  Specify the `--scale` so we can locate the right db's for the test.  Specify a `--dir` (local directory) to record the runtimes.

The output in `--dir` can be moved to **hdfs** and the queries in [evaluate](./evaluate) can be used to build the schema and correlate the stats that will compare the dimension runtimes.

Feedback
========

If you have questions, comments or problems, [contact me](emailto:dstreever@cloudera.com).

