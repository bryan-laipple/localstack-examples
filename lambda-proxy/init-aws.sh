#!/usr/bin/env bash
script=$(basename "${BASH_SOURCE}")
echo "${script} started"
#
# The community version of localstack does not support lambda container images.
# The lambda-proxy.zip package below can be used to create lambdas within localstack
# which will forward requests to a lambda container running externally to localstack.
# The external lambda container is expected to have a hostname matching the function
# name and be running the runtime interface emulator.
#
# The NodeJS handler below simply forwards a lambda request from localstack to
# another container/host matching the same name as the function. This is similar to
# executing a POST to the runtime interface emulator like:
#   curl "http://localhost:8080/2015-03-31/functions/function/invocations" -d '{}'
#
# Refer to: https://docs.aws.amazon.com/lambda/latest/dg/images-test.html
#
cat << EOF > lambda-proxy.js
const http = require('http');

const forward = function(functionName, body, callback) {
    const options = {
        hostname: functionName,
        port: 8080,
        path: '/2015-03-31/functions/function/invocations',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': body.length
        }
    };
    const req = http.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => callback(null, JSON.parse(data)));
    })
    req.on('error', (err) => callback(Error(err)));
    req.write(body);
    req.end();
}

exports.handler = function(event, context, callback) {
    forward(context.functionName, JSON.stringify(event), callback)
}
EOF

zip lambda-proxy.zip lambda-proxy.js

# create the lambda from the generic proxy handler zip
function_name="my-lambda"
awslocal lambda create-function \
--role arn:aws:iam::000000000000:role/lambda-role \
--handler lambda-proxy.handler \
--runtime nodejs14.x \
--zip-file fileb://lambda-proxy.zip \
--function-name ${function_name}

# create a DynamoDB table to make example more interesting
table_name="my-ddb-table"
awslocal dynamodb create-table --cli-input-json "$(cat <<-JSON
{
  "TableName": "${table_name}",
  "KeySchema": [
    {
      "AttributeName": "id",
      "KeyType": "HASH"
    }
  ],
  "AttributeDefinitions": [
    {
      "AttributeName": "id",
      "AttributeType": "S"
    }
  ],
  "ProvisionedThroughput": {
    "ReadCapacityUnits": 5,
    "WriteCapacityUnits": 5
  }
}
JSON
)"

# add a default item that includes the creation date of the table
awslocal dynamodb put-item --cli-input-json "$(cat <<-JSON
{
  "TableName": "${table_name}",
  "Item": {
    "id": { "S": "table-timestamp" },
    "val": { "S": "$(date)" }
  }
}
JSON
)"

sleep 1
echo "${script} finished"
