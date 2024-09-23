#!/bin/bash

# Output CSV file
output_file="bucket_sizes.csv"

# Write the header row to the CSV
echo "Bucket Name,Date,Size (GB)" > $output_file

# Function to get the size of a bucket on a specific date
get_bucket_size() {
    bucket_name=$1
    start_time=$2
    end_time=$3
    
    aws cloudwatch get-metric-statistics \
        --namespace AWS/S3 \
        --metric-name BucketSizeBytes \
        --dimensions Name=BucketName,Value=$bucket_name Name=StorageType,Value=StandardStorage \
        --start-time $start_time \
        --end-time $end_time \
        --period 86400 \
        --statistics Average \
        --query 'Datapoints[0].Average' --output text
}

# Get all the buckets
buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

# Loop through each bucket
for bucket in $buckets; do
    echo "Processing bucket: $bucket"
    
    # Calculate sizes for the 1st of each month for the last 6 months
    for i in {0..5}; do
        date=$(date -d "$i months ago 1st day" +"%Y-%m-%dT00:00:00Z")
        next_date=$(date -d "$i months ago 2nd day" +"%Y-%m-%dT00:00:00Z")
        
        size=$(get_bucket_size $bucket $date $next_date)
        
        if [[ $size == "None" ]]; then
            size_gb="No data"
        else
            size_gb=$(echo "$size / (1024 * 1024 * 1024)" | bc -l)
            size_gb=$(printf "%.2f" $size_gb) # Format to 2 decimal places
        fi
        
        # Append the result to the CSV file
        echo "$bucket,$date,$size_gb" >> $output_file
    done
done

echo "CSV report saved to $output_file"
