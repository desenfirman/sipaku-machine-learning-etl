# SIPAKU Real Time Air Quality Prediction

Part of SIPAKU (Sistem Pemantau Kualitas Udara)

SIPAKU Main Repository:

- from user:[desenfirman](https://github.com/desenfirman/sipaku) (forked repository)
- from user:[thomasariyanto](https://github.com/thomasaryanto/sipaku) (repository owner)

## A Brief Repository Structure

## Solution Architecture

The following diagram show the overall architecture for Real-Time Prediction feature.

![SIPAKU Machine Learning Solution Architecture](https://i.imgur.com/LFJYeV0.jpg)

## Data ETL

The following diagram show input and output in Data ETL phase.

![ETL Diagram](https://i.imgur.com/Cs3ZFmi.jpg)

Sipaku load data from DynamoDB table to EMR cluster machine using AWS DataPipeline Service. AWS DataPipeline provide transformation data from a stream-line DynamoDB into the time-series feature data before passing it into AWS SageMaker. On AWS DataPipeline service, we use a EC2 cluster running Hadoop and Hive as their Map-Reduce tools. The task in EC2 cluster is divided into 2 sub-task. The first task is dumping data from DynamoDB. We use a provided DataPipeline template to perform this operation.

![As we can se on this figure, there are 2 step/sub-task in this AWS DataPipeline](https://i.imgur.com/HAXGy6M.png)

After the first task is complete, we got a dumped data from DynamoDB. But the problem is output of the dumped data is in JSONLine and not in time series format. So we need to transform it into time series feature. We want to utilize some of active EMR cluster resource after the first task is complete. So, we add some new automation script after the first task is complete.

This automation script is loaded from Amazon S3 and running some Apache Hive query to transform stream-line JSONLine format into time-series .csv file. We also use a json-serde .jar plugin to make Apache Hive can detect JSONLine streamline format. The following partial code show how JSONLine is transformed into time-series .csv.

```bash
    #!/bin/bash

    # Convert DynamoDB export format to CSV for Machine Learning 
    hive -e "
    ADD jar s3://machine-learning-sipaku-dataset/json-serde-1.3.6-SNAPSHOT-jar-with-dependencies.jar ;
    DROP TABLE IF EXISTS sipaku_backup ;
    CREATE EXTERNAL TABLE sipaku_backup (  
        Value map<string,string>,
        Waktu map<string,string>,
        Tanggal map<string,string>
    ) 
    ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'  
    WITH SERDEPROPERTIES ('ignore.malformed.json' = 'true')
    LOCATION '$1/'
    ;

    INSERT OVERWRITE  DIRECTORY 's3://machine-learning-sipaku-dataset/sagemaker/' 
    SELECT CONCAT(final_table.y, ',', final_table.y_6, ',', final_table.y_5, ',', final_table.y_4, ',', final_table.y_3, ',', final_table.y_2, ',', final_table.y_1) as csv
    FROM (
        SELECT 
            LAG(sipaku_avg.avgr, 6) OVER (ORDER BY sipaku_avg.tgl) as y_6, 
            LAG(sipaku_avg.avgr, 5) OVER (ORDER BY sipaku_avg.tgl) as y_5, 
            LAG(sipaku_avg.avgr, 4) OVER (ORDER BY sipaku_avg.tgl) as y_4, 
            LAG(sipaku_avg.avgr, 3) OVER (ORDER BY sipaku_avg.tgl) as y_3, 
            LAG(sipaku_avg.avgr, 2) OVER (ORDER BY sipaku_avg.tgl) as y_2, 
            LAG(sipaku_avg.avgr, 1) OVER (ORDER BY sipaku_avg.tgl) as y_1, 
            sipaku_avg.avgr as y
        FROM (
            SELECT Tanggal['s'] as tgl, avg(Value['n']) as avgr
            FROM sipaku_backup
            GROUP BY Tanggal['s']) as sipaku_avg
        ) as final_table
    WHERE final_table.y_6 IS NOT NULL
    ;
    "
    if [ $? -ne 0 ]; then 
    echo "Error while running Hive SQL, Location - $1 "
    exit 1 ;
    fi
```

## Machine Learning Train-n-Deploy

After the DataPipeline phase is completed, then we perform some Machine Learning train n deploy task using AWS SageMaker. Briefly, AWS SageMaker is a service that provide a machine learning task like training and deploy model.

The training task can be achieved from AWS SageMaker Web Console. But we dont want to run training process manually by opening web console after ETL process is complete. Instead, we try to utilize some resource power from last ETL process to run a training task automatically. We run aws-cli inside those machine seamlessly to perform a training [plus] model deployment after ETL task is complete.

![Training model](https://i.imgur.com/Elvk80L.jpg)

[Full report of SIPAKU](https://docs.google.com/document/d/1IfSTj5QtwFh-Ooi6DRjt3teGczYhdKKIbzEIaCpWcuU) (Bahasa Indonesia)
