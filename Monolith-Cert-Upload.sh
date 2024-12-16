#!/bin/bash

set -e

# Function to log messages
log() {
    echo "[INFO] $1"
}

# Input parameters
NONPROD_ENVIRONMENTS="$1"    # NonProd environments selected
PROD_ENVIRONMENTS="$2"       # Prod environments selected

# Static or pre-configured values for the script
VAULT_NONPROD_ADDR="https://vault-nonprod.example.com"
VAULT_NONPROD_ROLE_ID="nonprod-role-id"
VAULT_NONPROD_SECRET_ID="nonprod-secret-id"
VAULT_PROD_ADDR="https://vault-prod.example.com"
VAULT_PROD_ROLE_ID="prod-role-id"
VAULT_PROD_SECRET_ID="prod-secret-id"
PKCS12_PASSWORD="example-password"
TODAY=$(date +"%Y-%m-%d")

# Map displayed values to actual environment values using associative arrays
declare -A NONPROD_MAP=(
    ["env1"]="nonprod-env-one"
    ["env2"]="nonprod-env-two"
    ["env3"]="nonprod-env-three"
    ["env4"]="nonprod-env-four"
    ["env5"]="nonprod-env-five"
    ["env6"]="nonprod-env-six"
    ["env7"]="nonprod-env-seven"
    ["env8"]="nonprod-env-eight"
    ["env9"]="nonprod-env-nine"
    ["env10"]="nonprod-env-ten"
    ["env11"]="nonprod-env-eleven"
)

declare -A PROD_MAP=(
    ["env1"]="prod-env-one"
    ["env2"]="prod-env-two"
    ["env3"]="prod-env-three"
    ["env4"]="prod-env-four"
)

# Function to authenticate to Vault using AppRole and set VAULT_TOKEN
vault_login() {
    local VAULT_ADDR="$1"
    local ROLE_ID="$2"
    local SECRET_ID="$3"

    log "Authenticating to Vault at ${VAULT_ADDR} with AppRole..."
    VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id="${ROLE_ID}" secret_id="${SECRET_ID}")
    echo "${VAULT_TOKEN}" # Return token
}

# Function to process certs and upload to Vault
process_vault_upload() {
    local ENVIRONMENTS="$1"       # List of environments (comma-separated)
    local VAULT_ADDR="$2"         # Vault address for the environment
    local ROLE_ID="$3"            # Vault AppRole Role ID
    local SECRET_ID="$4"          # Vault AppRole Secret ID
    local ENV_TYPE="$5"           # Environment type (NonProd/Prod)
    declare -n MAP="$6"           # Name-reference to the environment mapping array

    # Skip if no environments are provided
    if [[ -z "$ENVIRONMENTS" ]]; then
        log "No ${ENV_TYPE} environments selected. Skipping ${ENV_TYPE} upload."
        return
    fi

    # Authenticate to Vault and retrieve token
    VAULT_TOKEN=$(vault_login "${VAULT_ADDR}" "${ROLE_ID}" "${SECRET_ID}")

    # Export scoped Vault variables for subsequent commands
    export VAULT_ADDR="${VAULT_ADDR}"
    export VAULT_TOKEN="${VAULT_TOKEN}"
    log "Vault token and address set for ${ENV_TYPE}."

    log "Fetching public certificate, private key, and chain from Vault..."
    PUBLIC_CERT=$(vault kv get -field=public-cert "kv/staging-certificate-generation/${CERT_NAME}/public-cert")
    PRIVATE_KEY=$(vault kv get -field=private-key "kv/staging-certificate-generation/${CERT_NAME}/private-key")
    CHAIN_CERT=$(vault kv get -field=chain "kv/staging-certificate-generation/DHS-Treasury-chain")

    log "Creating PKCS12 file..."
    echo "${PUBLIC_CERT}" > public-cert.pem
    echo "${PRIVATE_KEY}" > private-key.pem
    echo "${CHAIN_CERT}" > chain.pem

    openssl pkcs12 -export -in public-cert.pem \
        -inkey private-key.pem -certfile chain.pem \
        -name "${CERT_NAME}" -out "${CERT_NAME}.p12" -passout pass:"${PKCS12PASSWORD}"

    log "Encoding PKCS12 file to Base64..."
    PKCS12_BASE64=$(base64 -w 0 "${CERT_NAME}.p12")

    IFS=',' read -ra ENVS <<< "$ENVIRONMENTS"
    for ENV in "${ENVS[@]}"; do
        # Use the mapping to get the actual value
        ACTUAL_ENV="${MAP[${ENV}]}"
        if [[ -z "${ACTUAL_ENV}" ]]; then
            log "No mapping found for '${ENV}'. Skipping."
            continue
        fi

        UPLOAD_PATH="kv/${ACTUAL_ENV}/${CERT_NAME}"
        log "Uploading PKCS12 to ${ENV_TYPE} Vault path: ${UPLOAD_PATH}"

        vault kv put "${UPLOAD_PATH}" \
            cert_type="PKCS12" \
            comment="Uploaded via Jenkins Job on ${TODAY}" \
            content="${PKCS12_BASE64}" \
            filename="${CERT_NAME}.pem" \
            fingerprint="${FINGERPRINT}" \
            storepass="${PKCS12PASSWORD}"
    done

    # Cleanup temporary files
    log "Cleaning up temporary files for ${ENV_TYPE} environments..."
    rm -f public-cert.pem private-key.pem chain.pem "${CERT_NAME}.p12"
}

# Process NonProd and Prod environments
log "Starting NonProd upload..."
process_vault_upload "${NONPROD_ENVIRONMENTS}" "${VAULT_NONPROD_ADDR}" "${VAULT_NONPROD_ROLE_ID}" "${VAULT_NONPROD_SECRET_ID}" "NonProd" NONPROD_MAP

log "Starting Prod upload..."
process_vault_upload "${PROD_ENVIRONMENTS}" "${VAULT_PROD_ADDR}" "${VAULT_PROD_ROLE_ID}" "${VAULT_PROD_SECRET_ID}" "Prod" PROD_MAP

log "Script completed successfully!"
