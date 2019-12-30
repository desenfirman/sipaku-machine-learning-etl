import boto3
import json 
import datetime

def lambda_handler(event, context):
    # TODO implement
    #!/usr/bin/env python


    sgm_client = boto3.client('sagemaker-runtime', region_name ='us-east-1')
    ddb_client = boto3.client('dynamodb', region_name ='us-east-1')
    
    response_ddb = ddb_client.scan(
        TableName="SIPAKUSensorData",
        AttributesToGet=[
            'Tanggal', 'Value'
        ]
    )
    data = response_ddb['Items']
    
    latest_data = dict()
    for x in data:
        if x['Tanggal']['S'] not in latest_data:
            latest_data[x['Tanggal']['S']] = list()
            # TODO: write code...\
        latest_data[x['Tanggal']['S']].append(float(x['Value']['N'])) 
    
    new_latest_data =  list()    
    for idx, value in latest_data.items():
        new_latest_data.append({'M': {'Tanggal': {'S' : idx}, 'Average': {'N' : str(sum(latest_data[idx]) / len(latest_data[idx]))}}})
    
    new_latest_data.sort(key=lambda x: datetime.datetime.strptime(x['M']['Tanggal']['S'], '%Y-%m-%d'))
    new_latest_data = new_latest_data[len(new_latest_data) - 6:]
    
    
    next_7_days = get_next_7_days(sgm_client, new_latest_data)
    
    now = datetime.datetime.now().strftime('%Y-%m-%d')
    start_from = datetime.datetime.strptime(new_latest_data[len(new_latest_data)-1]['M']['Tanggal']['S'], '%Y-%m-%d')
    
    
    result = ddb_client.put_item(Item={
            "PredID": {'S': "1"}, 
            "DateCreated": {'S': now},
            "DateStartPredict": {'S': start_from.strftime('%Y-%m-%d')},
            "PredictData": {'L': next_7_days} 
    }, TableName='SIPAKUPredictionResult')
        
    return {
        'statusCode': 200,
        'body': json.dumps(result)
    }
    
def predict_next_days(sgm_client, last_7_days):
    input_data = ""
    for i in range(len(last_7_days)):
        input_data += str(last_7_days[i]['M']['Average']['N'])
        if i < len(last_7_days) - 1:
            input_data += ","
                
    response = sgm_client.invoke_endpoint(
        EndpointName='ServiceEndpoint',
        Body=input_data, 
        ContentType='text/csv'
    )
    
    result = json.loads(response['Body'].read().decode())
    
    last_7_plus_pred = list(last_7_days)
    next_date = datetime.datetime.strptime(last_7_days[len(last_7_days) - 1]['M']['Tanggal']['S'], '%Y-%m-%d')
    next_date += datetime.timedelta(days=1)
    last_7_plus_pred.append({'M': {
        "Tanggal": {'S': next_date.strftime('%Y-%m-%d')},
        "Average": {'N': str(result['predictions'][0]['score'])}
        
    }})
    return last_7_plus_pred[1:]


def get_next_7_days(sgm_client, last_7_days_data):
    result = last_7_days_data
    for i in range(6):
        result = predict_next_days(sgm_client, result)
    return result
