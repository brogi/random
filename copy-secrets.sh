#!/bin/bash

# Source the vault login script to authenticate with Vault
source ./scripts/vault-login.sh

# Define the full path to the vault binary
VAULT_PATH="/usr/local/bin/vault"  # Update with the actual path to the vault binary

# Define the full path to the basename binary
BASENAME_PATH="/usr/bin/basename"

# Define the full path to the jq binary
JQ_PATH="/usr/local/bin/jq"

# Function to recursively list all secrets under a given path
# $1: Path to list secrets under
# $2: Output directory to save secret data
function list_secrets_recursive() {
    local PATH="$1"
    local OUTPUT_DIR="$2"

    echo "Listing secrets under path: ${PATH}"

    # List all secrets under the specified path
    local SECRET_LIST
    SECRET_LIST=$("${VAULT_PATH}" kv list -format=json "${PATH}" | "${JQ_PATH}" -r '.[]')

    # Loop through each secret
    for SECRET in ${SECRET_LIST}; do
        local SECRET_PATH="${PATH}/${SECRET}"

        if "${VAULT_PATH}" kv list -format=json "${SECRET_PATH}" >/dev/null 2>&1; then
            # If the secret path ends with "/", it indicates a nested directory, so recurse
            list_secrets_recursive "${SECRET_PATH}" "${OUTPUT_DIR}"
        else
            # Otherwise, it retrieves and saves the secret data
            echo "Reading secret data from: ${SECRET_PATH}"
            local SECRET_DATA
            SECRET_DATA=$("${VAULT_PATH}" kv get -format=json "${SECRET_PATH}" | "${JQ_PATH}" -r '.data')

            # Extract the secret name from the path
            local SECRET_NAME
            SECRET_NAME=$("${BASENAME_PATH}" "${SECRET_PATH}")

            # Save the secret data to a JSON file in the output directory
            local OUTPUT_FILE="${OUTPUT_DIR}/${SECRET_NAME}.json"
            echo "${SECRET_DATA}" >"${OUTPUT_FILE}"
            echo "Secret data saved to ${OUTPUT_FILE}"
        fi
    done
}

# Define the output directory
OUTPUT_DIR="cert-files/working-directory"

# Create the output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Prompt user for source path
read -p "Enter source path (e.g., kv/sky): " SOURCE_PATH

echo "Source path entered: ${SOURCE_PATH}"

# Validate source path
if [ -z "${SOURCE_PATH}" ]; then
    echo "Error: Source path is empty. Please provide a valid path."
    exit 1
fi

# Call the function to recursively list secrets under the specified path
list_secrets_recursive "${SOURCE_PATH}" "${OUTPUT_DIR}"

echo "All secrets from ${SOURCE_PATH} and its nested paths saved to ${OUTPUT_DIR} successfully."
