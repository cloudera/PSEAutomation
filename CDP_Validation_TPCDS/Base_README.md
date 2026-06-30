# CDP_IHV_Validation

This repo contains the following tests as part of the CDP Validation for our IHV partners. 

### Terasuite: 
This suite consists of three tests namely, Teragen, Terasort, and Teravalidate. 
Click [here](https://github.infra.cloudera.com/pkatti/CDP_IHV_Validation/tree/main/Terasuite) to check the details of Terasuite. 


### TPC-DS
**Hive:** Click [here](https://github.infra.cloudera.com/pkatti/CDP_IHV_Validation/tree/main/hive-tpcds-kit) to proceed with Hive TPC-DS test. 

**Impala:** Click [here](https://github.infra.cloudera.com/pkatti/CDP_IHV_Validation/tree/main/impala-tpcds-kit) to proceed with Impala TPC-DS test. 

You will need to perform these tests on the gateway/edge node. If you don’t have an edge node in your cluster, please feel free to run this on any datanode. 

Please note that the choice of scale is up to you. We generally recommend running the tests for 1T data volume. If your requirement is to run it for higher volume, please feel free to do so. However, those might need some tweaking in the resource configuration. 
