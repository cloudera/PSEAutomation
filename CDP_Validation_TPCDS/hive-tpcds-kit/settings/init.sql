set hive.map.aggr=true;
set mapreduce.reduce.speculative=false;
set hive.auto.convert.join=true;
-- default 4
set hive.optimize.reducededuplication.min.reducer=1;
-- default not set
set hive.optimize.mapjoin.mapreduce=true;
set hive.stats.autogather=true;

set mapred.reduce.parallel.copies=30;
-- set mapred.job.shuffle.input.buffer.percent=0.5;
-- set mapred.job.reduce.input.buffer.percent=0.2;
set mapred.map.child.java.opts=-server -Xmx2800m -Djava.net.preferIPv4Stack=true;
set mapred.reduce.child.java.opts=-server -Xmx3800m -Djava.net.preferIPv4Stack=true;
set mapreduce.map.memory.mb=3072;
set mapreduce.reduce.memory.mb=4096;
-- Not on the default whitelist
-- set hive.llap.memory.oversubscription.max.executors.per.query=8;
-- Not on the default whitelist
-- set hive.llap.mapjoin.memory.oversubscribe.factor=0.3;
-- default 21000000
set hive.auto.convert.join.hashtable.max.entries=-1;
set hive.optimize.bucketmapjoin=false;
set hive.convert.join.bucket.mapjoin.tez=false;
set hive.auto.convert.join.shuffle.max.size=10000000000;
set hive.tez.llap.min.reducer.per.executor=0.33;
-- Not on the default whitelist
--set hive.map.aggr.hash.min.reduction=0.99;

-- default -1
-- I think this setting is the one messing up query11 and crash/hanging HS2
set hive.optimize.sort.dynamic.partition.threshold=0;

-- Turn off Query Results Cache to prevent repeated runs from skew.
set hive.query.results.cache.enabled=false;