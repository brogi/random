import os
import subprocess
import yaml

# Path to the values.yaml file
YAML_FILE = "values.yaml"

# Vault path for fetching certs
VAULT_ENV_PATH = "kv/staging-certificate-files"
KEYSTORE_PASSWORD = "keystorepass"
TRUSTSTORE_PASSWORD = "truststorepass"

KEYSTORE_FILE = "keystore.jks"
TRUSTSTORE_FILE = "truststore.jks"

# Load cert names from the YAML file
with open(YAML_FILE, 'r') as file:
    certs = yaml.safe_load(file)['certs']

truststore_certs = certs['truststore']
keystore_certs = certs['keystore']

# Clean up any existing keystore/truststore
if os.path.exists(KEYSTORE_FILE):
    os.remove(KEYSTORE_FILE)
if os.path.exists(TRUSTSTORE_FILE):
    os.remove(TRUSTSTORE_FILE)

def vault_get(field, cert_name):
    """Fetch a field from Vault for a specific certificate."""
    cmd = ["vault", "kv", "get", "-field", field, f"{VAULT_ENV_PATH}/{cert_name}"]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
    return result.stdout.strip()

def add_to_truststore(cert_name):
    """Add a certificate to the truststore."""
    public_cert = vault_get("public_cert", cert_name)
    
    with open(f"{cert_name}_public_cert.pem", "w") as f:
        f.write(public_cert)
    
    cmd = [
        "keytool", "-import", "-trustcacerts", "-alias", cert_name,
        "-file", f"{cert_name}_public_cert.pem", "-keystore", TRUSTSTORE_FILE,
        "-storepass", TRUSTSTORE_PASSWORD, "-noprompt"
    ]
    
    subprocess.run(cmd)
    os.remove(f"{cert_name}_public_cert.pem")

def add_to_keystore(cert_name):
    """Add a certificate to the keystore."""
    public_cert = vault_get("public_cert", cert_name)
    private_key = vault_get("private_key", cert_name)
    cert_chain = vault_get("cert_chain", cert_name)
    
    # Save certs temporarily
    with open(f"{cert_name}_public_cert.pem", "w") as f:
        f.write(public_cert)
    with open(f"{cert_name}_private_key.pem", "w") as f:
        f.write(private_key)
    with open(f"{cert_name}_cert_chain.pem", "w") as f:
        f.write(cert_chain)
    
    # Convert private key and certificate chain into a PKCS12 file
    pkcs12_file = f"{cert_name}.p12"
    openssl_cmd = [
        "openssl", "pkcs12", "-export",
        "-in", f"{cert_name}_public_cert.pem",
        "-inkey", f"{cert_name}_private_key.pem",
        "-certfile", f"{cert_name}_cert_chain.pem",
        "-out", pkcs12_file,
        "-name", cert_name, "-passout", f"pass:{KEYSTORE_PASSWORD}"
    ]
    
    subprocess.run(openssl_cmd)
    
    # Import the PKCS12 keystore into a JKS keystore
    keytool_cmd = [
        "keytool", "-importkeystore",
        "-srckeystore", pkcs12_file, "-srcstoretype", "PKCS12",
        "-srcstorepass", KEYSTORE_PASSWORD,
        "-destkeystore", KEYSTORE_FILE, "-deststorepass", KEYSTORE_PASSWORD,
        "-alias", cert_name
    ]
    
    subprocess.run(keytool_cmd)
    
    # Cleanup temporary files
    os.remove(f"{cert_name}_public_cert.pem")
    os.remove(f"{cert_name}_private_key.pem")
    os.remove(f"{cert_name}_cert_chain.pem")
    os.remove(pkcs12_file)

# Process the truststore certificates
for cert_name in truststore_certs:
    print(f"Adding {cert_name} to truststore...")
    add_to_truststore(cert_name)

# Process the keystore certificates
for cert_name in keystore_certs:
    print(f"Adding {cert_name} to keystore...")
    add_to_keystore(cert_name)

# Store the keystore and truststore back into Vault
subprocess.run(["vault", "kv", "put", f"kv/$ENVIRONMENT/$SERVICE_NAME/keystore", f"keystore=@{KEYSTORE_FILE}"])
subprocess.run(["vault", "kv", "put", f"kv/$ENVIRONMENT/$SERVICE_NAME/truststore", f"truststore=@{TRUSTSTORE_FILE}"])

# Clean up keystore and truststore files
os.remove(KEYSTORE_FILE)
os.remove(TRUSTSTORE_FILE)
