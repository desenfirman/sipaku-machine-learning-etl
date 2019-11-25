#!/bin/bash


# upgrade CLI for sagemaker 
pip install awscli --upgrade --user

## Define variable   
REGION="us-east-1"
ROLE="arn:aws:iam::193207549232:role/service-role/AmazonSageMaker-ExecutionRole-20191107T152136" 
DTTIME=`date +%Y-%m-%d-%H-%M-%S` 
echo  $REGION


# Select  containers image for training and deploy 
case "$REGION" in
"us-west-2" )
    IMAGE="174872318107.dkr.ecr.us-west-2.amazonaws.com/linear-learner:latest"
    ;;
"us-east-1" )
    IMAGE="382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:latest" 
    ;;
"us-east-2" )
    IMAGE="404615174143.dkr.ecr.us-east-2.amazonaws.com/linear-learner:latest" 
    ;;
"eu-west-1" )
    IMAGE="438346466558.dkr.ecr.eu-west-1.amazonaws.com/linear-learner:latest" 
    ;;
 *)
    echo "Invalid Region Name or Amazon SageMaker is not supported in this region."
    exit 1 ;  
esac

  
# Training job and  model artifact 
TRAINING_JOB_NAME=TRAIN-${DTTIME} 
S3OUTPUT="s3://machine-learning-sipaku-dataset/model/" 
INSTANCETYPE="ml.m4.xlarge"
INSTANCECOUNT=1
VOLUMESIZE=5 
aws sagemaker create-training-job \
    --training-job-name ${TRAINING_JOB_NAME} \
    --region ${REGION} \
    --algorithm-specification TrainingImage=${IMAGE},TrainingInputMode=Pipe \
    --role-arn ${ROLE} \
    --input-data-config '[{ "ChannelName": "train", "DataSource": {
         "S3DataSource": { "S3DataType": "S3Prefix", "S3Uri": "s3://machine-learning-sipaku-dataset/sagemaker/", "S3DataDistributionType": "FullyReplicated" } }, "ContentType": "text/csv", "CompressionType": "None" , "RecordWrapperType": "None"  }]'  \
    --output-data-config S3OutputPath=${S3OUTPUT} \
    --resource-config InstanceType=${INSTANCETYPE},InstanceCount=${INSTANCECOUNT},VolumeSizeInGB=${VOLUMESIZE} \
    --stopping-condition MaxRuntimeInSeconds=120 \
    --hyper-parameters feature_dim=6,predictor_type='regressor',mini_batch_size=14

# wait until job completed 
aws sagemaker wait training-job-completed-or-stopped --training-job-name ${TRAINING_JOB_NAME}  --region ${REGION}

# create model
MODELARTIFACT=`aws sagemaker describe-training-job --training-job-name ${TRAINING_JOB_NAME} --region ${REGION}  --query 'ModelArtifacts.S3ModelArtifacts' --output text `
MODELNAME=MODEL-${DTTIME}
aws sagemaker create-model --region ${REGION} --model-name ${MODELNAME}  --primary-container Image=${IMAGE},ModelDataUrl=${MODELARTIFACT}  --execution-role-arn ${ROLE}


# create end point configuration 
CONFIGNAME=CONFIG-${DTTIME}
aws sagemaker  create-endpoint-config --region ${REGION} --endpoint-config-name ${CONFIGNAME}  --production-variants  VariantName=Users,ModelName=${MODELNAME},InitialInstanceCount=1,InstanceType=ml.m4.xlarge


# create end point 
STATUS=`aws sagemaker describe-endpoint --endpoint-name  ServiceEndpoint --query 'EndpointStatus' --output text --region ${REGION} `
if [[ $STATUS -ne "InService" ]] ;
then
    aws sagemaker  create-endpoint --endpoint-name  ServiceEndpoint  --endpoint-config-name ${CONFIGNAME} --region ${REGION}    
else
    aws sagemaker  update-endpoint --endpoint-name  ServiceEndpoint  --endpoint-config-name ${CONFIGNAME} --region ${REGION}
fi 
