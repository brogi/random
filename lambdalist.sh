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

#!/bin/bash

# Print the CSV header
echo "Function Name,Last Invoked Time"

# Fetch all Lambda functions
functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)

# Loop through each function and get the last invocation date
for function in $functions; do
    # Use the MacOS compatible `date` command for the past year
    start_time=$(date -u -v-1y +%Y-%m-%dT%H:%M:%SZ)
    end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Get the last invoked date from CloudWatch logs for the past year
    last_invoked=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Invocations \
        --dimensions Name=FunctionName,Value=$function \
        --statistics Sum \
        --start-time $start_time \
        --end-time $end_time \
        --period 86400 \
        --query 'Datapoints[0].Timestamp' \
        --output text)

    # Print the function name and last invocation date in CSV format
    echo "$function,${last_invoked:-Never}"
done


#!/bin/bash

# Print the CSV header
echo "Function Name,Last Invoked Time"

# Fetch all Lambda functions
functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)

# Loop through each function to get the last invocation date
for function in $functions; do
    # Use AWS CloudTrail to find the last invocation event for the past year
    last_invoked=$(aws cloudtrail lookup-events \
        --lookup-attributes AttributeKey=EventName,AttributeValue=Invoke \
        --query "Events[?Resources[?ResourceName=='$function']].EventTime | sort(@) | [-1]" \
        --output text)

    # Print the function name and last invocation date in CSV format
    echo "$function,${last_invoked:-Never}"
done

#!/bin/bash

# Print the CSV header
echo "Function Name,Last Invoked Time"

# Fetch all Lambda functions
functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)

# Loop through each function to get the last invocation time from CloudWatch Logs
for function in $functions; do
    # Define the log group name
    log_group="/aws/lambda/$function"

    # Use CloudWatch Logs Insights to get the most recent invocation time
    last_invoked=$(aws logs start-query \
        --log-group-name "$log_group" \
        --start-time $(date -v-1y +%s) \
        --end-time $(date +%s) \
        --query-string "fields @timestamp | sort @timestamp desc | limit 1" \
        --query 'queryId' \
        --output text)

    # Wait for the query to complete
    query_status="Running"
    while [ "$query_status" == "Running" ] || [ "$query_status" == "Scheduled" ]; do
        sleep 1
        query_status=$(aws logs get-query-results --query-id "$last_invoked" --query 'status' --output text)
    done

    # Get the timestamp of the last invocation
    timestamp=$(aws logs get-query-results --query-id "$last_invoked" \
        --query 'results[0][0].value' --output text)

    # Print the function name and last invocation date in CSV format
    echo "$function,${timestamp:-Never}"
done

