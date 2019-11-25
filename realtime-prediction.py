#!/usr/bin/env python

import boto3
import json 

client = boto3.client('sagemaker-runtime', region_name ='eu-west-1' )
new_customer_info = '34,10,2,4,1,2,1,1,6,3,190,1,3,4,3,-1.7,94.055,-39.8,0.715,4991.6'

response = client.invoke_endpoint(
    EndpointName='ServiceEndpoint',
    Body=new_customer_info , 
    ContentType='text/csv'
)

result = json.loads(response['Body'].read().decode())
print(result) 
