#!/bin/bash

# Prompt for the environment
read -p "Enter environment (e.g., staging, production): " ENVIRONMENT

# Vault path for the KV secrets
SECRET_PATH="kv/${ENVIRONMENT}/"

# Output CSV file
OUTPUT_FILE="secrets_version_dates_${ENVIRONMENT}_18months.csv"

# Get the date 18 months ago (using BSD date syntax for macOS)
CUT_OFF_DATE=$(date -v -18m +"%Y-%m-%d")

# Write the CSV header
echo "Secret Name,Most Recent Version Date" > $OUTPUT_FILE

# Get a list of all secrets in the directory and print for debugging
SECRETS=$(vault list -format=json ${SECRET_PATH})
echo "Secrets in path: $SECRET_PATH"
echo $SECRETS | jq .

# Check if SECRETS is empty
if [[ -z "$SECRETS" ]]; then
  echo "No secrets found at path $SECRET_PATH"
  exit 1
fi

SECRETS=$(echo $SECRETS | jq -r '.[]')

# Loop through each secret and get the metadata (latest version info)
for secret in $SECRETS; do
  echo "Processing secret: $secret" # Debugging output
  
  # Retrieve metadata for the secret and print for debugging
  METADATA=$(vault read -format=json kv/metadata/${ENVIRONMENT}/${secret})
  echo "Metadata for $secret:"
  echo $METADATA | jq .

  # Extract the creation date of the most recent version and strip the time
  CREATED_TIME=$(echo $METADATA | jq -r '.data.versions | max_by(.version) | .created_time' | cut -d'T' -f1)
  echo "Created time: $CREATED_TIME" # Debugging output

  # Compare the created_time with the cutoff date
  if [[ "$CREATED_TIME" < "$CUT_OFF_DATE" ]]; then
    echo "Secret $secret is older than $CUT_OFF_DATE" # Debugging output
    # Append the secret name and most recent version date to the CSV file
    echo "$secret,$CREATED_TIME" >> $OUTPUT_FILE
  else
    echo "Secret $secret is newer than $CUT_OFF_DATE" # Debugging output
  fi
done

# Notify the user
echo "CSV file saved as $OUTPUT_FILE"
