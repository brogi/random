!/bin/bash

# Define the full path to the vault binary
VAULT_PATH="/usr/local/bin/vault"  # Update with the actual path to the vault binary

# Function to recursively list all secrets under a given path
# $1: Path to list secrets under
# $2: Output directory to save secret data
function list_secrets_recursive() {
    local PATH="$1"
    local OUTPUT_DIR="$2"

    echo "Listing secrets under path: ${PATH}"

    # List all secrets under the specified path
    local LIST_OUTPUT
    LIST_OUTPUT=$("${VAULT_PATH}" kv list -format=json "${PATH}")

    # Check if the path ends with "/"
    if [[ "${LIST_OUTPUT: -1}" == "/" ]]; then
        # Path is a directory (contains sub-paths), so recursively process each sub-path
        local SUB_PATHS
        SUB_PATHS=$(echo "${LIST_OUTPUT}" | jq -r '.[]')

        for SUB_PATH in ${SUB_PATHS}; do
            # Construct the full sub-path
            local FULL_PATH="${PATH}${SUB_PATH}"

            # Recursively list secrets under the sub-path
            list_secrets_recursive "${FULL_PATH}" "${OUTPUT_DIR}"
        done
    else
        # Path is a leaf node (contains secrets), so retrieve and save secret data
        local SECRET_DATA
        SECRET_DATA=$("${VAULT_PATH}" kv get -format=json "${PATH}" | jq -r '.data')

        # Save the secret data to a JSON file
        local SECRET_NAME
        SECRET_NAME=$(basename "${PATH}")  # Extract the last part of the path as the secret name
        local OUTPUT_FILE="${OUTPUT_DIR}/${SECRET_NAME}.json"
        echo "${SECRET_DATA}" >"${OUTPUT_FILE}"
        echo "Secret data saved to ${OUTPUT_FILE}"
    fi
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
