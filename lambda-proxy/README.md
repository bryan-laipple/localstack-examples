# Using Lambda Container Images with LocalStack
The community version of LocalStack does not support AWS Lambda functions packaged
as container images. The example in this directory creates a lambda packaged as a
`.zip` which proxies requests to a container running external to the LocalStack
container leveraging the runtime interface emulator available with AWS Lambda images.

References:
- 

## Files

### Dockerfile
This Dockerfile defines an AWS Lambda function container image.  The handler will
either query a DynamoDB table named `my-ddb-table` or print a `Hello World` statement
depending on the payload included when invoking the function.

### docker-compose.yml
This file defines two containers; a `localstack` container and an AWS Lambda function
container named `my-lambda` built from the Dockerfile. The `localstack` container is
initialized by running the `aws-init.sh` script during startup.  The environment
variables passed to the `my-lambda` container are necessary to enable the AWS SDK to
communicate with the `localstack` container.  These environment variables configure
the endpoint-url, region, and dummy authentication settings that are used when
constructing clients for AWS services. 

### init-aws.sh
This initialization script creates some AWS resources in the `localstack` container on startup.
It creates a `.zip` file containing a NodeJS AWS Lambda handler that forwards requests to a host matching the function name.
It then defines an AWS Lambda function named `my-lambda` using the `.zip` package.
A DynamoDB table named `my-ddb-table` is created and an item with `id=table-timestamp` is added to the table.
## Demo

### Prerequisites
To support the features used by this demo, the tooling requires specific versions:
- [Dockerfile syntax 1.4.0+ supporting heredocs](https://docs.docker.com/engine/reference/builder/#here-documents)
- [AWS CLI 2.13.0+ supporting endpoint-url configuration](https://aws.amazon.com/blogs/developer/new-improved-flexibility-when-configuring-endpoint-urls-with-the-aws-sdks-and-tools/)

### Configuration
The environment can be configured via the `aws configure` command then updating the `~/.aws/config` entry to include an `endpoint_url` value.
First run the `configure` command using a profile named `localstack`:
```
$ aws --profile localstack configure
AWS Access Key ID [None]: localstack
AWS Secret Access Key [None]: localstack
Default region name [None]: us-east-1
Default output format [None]: json
```
Then manually edit `~/.aws/config` to set `endpoint_url` to point to the mapped localstack port:
```
[profile localstack]
region = us-east-1
output = json
endpoint_url = http://localhost:4566
```
The `~/.aws/credentials` file should contain the access key info (these can be any value):
```
[localstack]
aws_access_key_id     = localstack
aws_secret_access_key = localstack
```

Alternatively to setting up a profile, the following environment variables can be set and the `--endpoint-url` argument can be used when executing CLI commands:
```
AWS_ACCESS_KEY_ID=localstack \
AWS_SECRET_ACCESS_KEY=localstack \
AWS_DEFAULT_REGION=us-east-1 \
aws --endpoint-url http://localhost:4566 \
<service> <command> <args>
```
### Commands
1. Start the containers.  You'll see an `init-aws.sh finished` message when localstack is finished starting up.
```
docker-compose up
```
2. Confirm the AWS Lambda function is running using the runtime interface emulator.
```
curl "http://localhost:8080/2015-03-31/functions/function/invocations" -d '{}'
```
3. Invoke the function using the CLI pointed to localstack.
```
aws --profile localstack \
lambda invoke --function-name my-lambda \
response.txt && cat response.txt
```
4. Invoke the function using the CLI with a payload to fetch an item out of the DynamoDB table.
```
aws --profile localstack \
lambda invoke --function-name my-lambda \
--cli-binary-format raw-in-base64-out \
--payload '{"id": "table-timestamp"}' \
response.json && cat response.json
```
