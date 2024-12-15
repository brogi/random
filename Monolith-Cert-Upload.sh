#!/bin/bash

# Monolith-Cert-Upload.sh
# Script to fetch certs from Vault, create PKCS12, and upload to selected environments

set -e

# Variables
CN=""
VAULT_ADDR="https://vault.example.com" # Replace with your Vault address
PKCS12PASSWORD="${PKCS12PASSWORD}"    # Passed as environment variable
SELECTED_OPTIONS="${SELECTED_OPTIONS}" # Environments passed from Jenkinsfile
VAULT_TOKEN="${VAULT_TOKEN}"          # Ensure Vault token is exported in the environment

# Function to log messages
log() { echo "[INFO] $1"; }

# Step 1: Extract CN from public certificate
CERT_PATH="path/to/public-cert.pem" # Replace with the actual certificate path
CN=$(openssl x509 -noout -subject -in "$CERT_PATH" | sed -n 's/.*CN=\([^,/]*\).*/\1/p')

log "Extracted CN: ${CN}"

# Step 2: Fetch secrets from Vault
VAULT_PUBLIC_CERT="kv/staging-certificate-generation/${CN}"
VAULT_CA_CHAIN="kv/staging-certificate-generation/DHS-Treasury-chain"

log "Fetching secrets from Vault..."

PUBLIC_CERT=$(vault kv get -field=public-cert "$VAULT_PUBLIC_CERT")
PRIVATE_KEY=$(vault kv get -field=private-key "$VAULT_PUBLIC_CERT")
CA_CHAIN=$(vault kv get -field=chain "$VAULT_CA_CHAIN")

# Step 3: Write cert, key, and chain to files
log "Writing cert, key, and CA chain to files..."

echo "$PUBLIC_CERT" > public-cert.pem
echo "$PRIVATE_KEY" > private-key.pem
echo "$CA_CHAIN" > ca-chain.pem

# Step 4: Create PKCS12 file
log "Creating PKCS12 file..."

openssl pkcs12 -export \
    -in public-cert.pem \
    -inkey private-key.pem \
    -certfile ca-chain.pem \
    -out cert-bundle.p12 \
    -password pass:"$PKCS12PASSWORD"

# Step 5: Encode PKCS12 to Base64
log "Encoding PKCS12 file to Base64..."

PKCS12_BASE64=$(base64 -w 0 cert-bundle.p12)

# Step 6: Upload PKCS12 to each selected environment
IFS=',' read -ra ENVIRONMENTS <<< "$SELECTED_OPTIONS"

for ENV in "${ENVIRONMENTS[@]}"; do
    UPLOAD_PATH="kv/${ENV}/${CN}"
    log "Uploading PKCS12 to Vault path: ${UPLOAD_PATH}"

    vault kv put "${UPLOAD_PATH}" pkcs12="${PKCS12_BASE64}"
done

log "PKCS12 upload complete!"
