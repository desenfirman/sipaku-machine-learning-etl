#!/bin/bash

# Convert DynamoDB export format to CSV for Machine Learning 
/opt/hive/bin/hive -e "
ADD jar json-serde-1.3.6-SNAPSHOT-jar-with-dependencies.jar ; 
DROP TABLE IF EXISTS sipaku_backup ; 
CREATE EXTERNAL TABLE sipaku_backup (  
    Value map<string,string>, 
    Waktu map<string,string>, 
    Tanggal map<string,string> 
) 
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'  
WITH SERDEPROPERTIES ('ignore.malformed.json' = 'true')
LOCATION 's3://machine-learning-dese/test/c81eaaba-a92c-4f38-9f58-a4c2c4a0246f'
;

"
if [ $? -ne 0 ]; then 
  echo "Error while running Hive SQL, Location - $1 "
  exit 1 ; 
fi
