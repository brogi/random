#!/bin/bash

# Fetch all Lambda functions
functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)

echo "Function Name | Last Invoked Time"

# Loop through each function and get the last invocation date
for function in $functions; do
    # Get the last invoked date from CloudWatch logs
    last_invoked=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Invocations \
        --dimensions Name=FunctionName,Value=$function \
        --statistics Sum \
        --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
        --period 86400 \
        --query 'Datapoints[0].Timestamp' \
        --output text)

    # Print the function name and last invocation date
    echo "$function | ${last_invoked:-Never}"
done
