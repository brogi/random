#!/bin/bash

# Output CSV file
output_file="bucket_sizes.csv"
# Write the header row to the CSV
echo "Bucket Name,Date,Size (GB),Storage Class" > $output_file

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

# Function to get the storage class of a bucket
get_storage_class() {
    bucket_name=$1
    aws s3api get-bucket-storage-class-analysis --bucket "$bucket_name" \
        --query "StorageClassAnalysis.DataExport.OutputSchema" --output text
}

# Get all the buckets
buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

# Loop through each bucket
for bucket in $buckets; do
    echo "Processing bucket: $bucket"
    
    # Get the storage class
    storage_class=$(get_storage_class $bucket)

    # Calculate sizes for the 1st of each month for the last 6 months
    for i in {0..5}; do
        date=$(date -v -"$i"m -v1d +"%Y-%m-%dT00:00:00Z")
        next_date=$(date -v -"$i"m -v2d +"%Y-%m-%dT00:00:00Z")
        size=$(get_bucket_size $bucket $date $next_date)
        
        if [[ $size == "None" ]]; then
            size_gb="No data"
        else
            size_gb=$(echo "$size / (1024 * 1024 * 1024)" | bc -l)
            size_gb=$(printf "%.2f" $size_gb) # Format to 2 decimal places
        fi
        
        # Append the result to the CSV file
        echo "$bucket,$date,$size_gb,$storage_class" >> $output_file
    done
done

echo "CSV report saved to $output_file"
