# syntax=docker/dockerfile:1.4.0
FROM public.ecr.aws/lambda/python:3.11

# Copy requirements.txt
COPY <<EOF ${LAMBDA_TASK_ROOT}/requirements.txt
boto3==1.28.0
EOF

# Copy function code
COPY <<EOF ${LAMBDA_TASK_ROOT}/lambda.py
import boto3

client = boto3.client('dynamodb')

def handler(event, context):
    if 'id' in event:
        return client.get_item(TableName='my-ddb-table', Key={'id':{'S':event['id']}}).get('Item')
    else:
        return 'Howdy from AWS Lambda packaged as a container image!'
EOF

# Install the specified packages
RUN pip install -r requirements.txt

# Set the CMD to the function handler
CMD [ "lambda.handler" ]
