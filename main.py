import os
import hashlib
import base64
import json
import logging
import subprocess
import time
import threading
from pathlib import Path
from flask import Flask, jsonify, Response
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Initialize Flask
app = Flask(__name__)

# Default parameters
CERT_DIR = os.getenv("CERT_DIR", "/app/certs")
CERT_PATH = os.getenv("CERT_PATH", f"{CERT_DIR}/fullchain.pem")
KEY_PATH = os.getenv("KEY_PATH", f"{CERT_DIR}/privkey.pem")
ACME_JSON_PATH = os.getenv("ACME_JSON_PATH", "/app/data/acme.json")
DOMAIN = os.getenv("DOMAIN")
RESOLVER = os.getenv("RESOLVER", "letsencrypt")
VERBOSITY = os.getenv("VERBOSITY", "INFO").upper()
IP_ADDRESS = os.getenv("IP_ADDRESS", "127.0.0.1")

# Variable to store the current certificate hash
cert_hash = ""

# Configure the logger
logging.basicConfig(level=getattr(logging, VERBOSITY, logging.INFO))
logger = logging.getLogger("CertUpdater")

# Check for required environment variables
def check_required_env_vars():
    if not DOMAIN or not RESOLVER:
        missing_vars = [var for var in ["DOMAIN", "RESOLVER"] if not os.getenv(var)]
        logger.error("Missing required environment variables: %s", ', '.join(missing_vars))
        exit(1)

# Read the acme.json file
def read_acme_json():
    try:
        with open(ACME_JSON_PATH) as file:
            return json.load(file)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        logger.error("Error reading acme.json file: %s", e)
        return None

# Calculate the hash of given data
def calculate_hash(data):
    return hashlib.sha256(data.encode()).hexdigest()

# Check if the certificate has changed
def has_cert_changed(new_cert):
    global cert_hash
    current_hash = calculate_hash(new_cert)
    if cert_hash != current_hash:
        cert_hash = current_hash
        return True
    return False

# Update certificates
def update_certs():
    acme_data = read_acme_json()
    if not acme_data:
        return

    cert_entry = next(
        (
            cert
            for cert in acme_data.get(RESOLVER, {}).get("Certificates", [])
            if cert.get("domain", {}).get("main") == DOMAIN
        ),
        None,
    )

    if cert_entry:
        cert_b64 = cert_entry.get("certificate")
        key_b64 = cert_entry.get("key")

        if cert_b64 and key_b64:
            cert_decoded = base64.b64decode(cert_b64).decode("utf-8")
            key_decoded = base64.b64decode(key_b64).decode("utf-8")

            # Check if the certificate files are missing or if the certificate has changed
            if not Path(CERT_PATH).exists() or not Path(KEY_PATH).exists() or has_cert_changed(cert_decoded):
                with open(CERT_PATH, "w") as cert_file, open(KEY_PATH, "w") as key_file:
                    cert_file.write(cert_decoded)
                    key_file.write(key_decoded)

                os.chmod(CERT_PATH, 0o600)
                os.chmod(KEY_PATH, 0o600)
                logger.info("Certificate and key updated for %s.", DOMAIN)
            else:
                logger.info("The certificate for %s has not changed.", DOMAIN)
        else:
            logger.warning("Missing certificate or key for %s. Attempting regeneration.", DOMAIN)
            force_update()
            update_certs()
    else:
        logger.error("Certificate entry not found for domain %s in acme.json.", DOMAIN)

# Verify the certificate
def verify_cert():
    try:
        result = subprocess.run(
            ["openssl", "s_client", "-servername", DOMAIN, "-connect", f"{IP_ADDRESS}:443", "-showcerts"],
            capture_output=True,
            text=True,
            input="",
            timeout=10
        )
        output = result.stdout
        logger.debug("Full openssl output:\n%s", output)
        for line in output.splitlines():
            if "NotAfter" in line:
                expiration_date = line.split("NotAfter:")[1].strip()
                logger.info("The certificate is valid until: %s", expiration_date)
                return True
        logger.warning("Expiration date 'NotAfter' not found. OpenSSL output:\n%s", output)
        return False
    except subprocess.TimeoutExpired:
        logger.error("Certificate verification timed out.")
        return False
    except Exception as e:
        logger.error("Error verifying the certificate: %s", e)
        return False

# Test DNS-over-TLS resolution
def test_dot_resolution():
    try:
        result = subprocess.run(
            [
                "kdig", "-d", f"@{DOMAIN}", "+tls", "+tls-ca", f"+tls-host={DOMAIN}", "google.com"
            ],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and "status: NOERROR" in result.stdout:
            logger.info("DNS-over-TLS resolution is functional.")
            return True
        else:
            logger.warning("DNS-over-TLS resolution failed.")
            return False
    except Exception as e:
        logger.error("Error testing DNS-over-TLS resolution: %s", e)
        return False

# Force the certificate update
def force_update():
    logger.info("Forcing certificate update via Traefik...")
    subprocess.run(["curl", "-s", "-o", "/dev/null", "--resolve", f"{DOMAIN}:443:{IP_ADDRESS}", f"https://{DOMAIN}"])
    logger.debug("Waiting for Traefik to update the certificate.")
    time.sleep(10)

# File handler for Watchdog
class AcmeFileHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path == ACME_JSON_PATH:
            logger.info("Detected change in %s. Updating certificates.", ACME_JSON_PATH)
            update_certs()
            verify_cert()

# Watch the acme.json file
def watch_acme_file():
    event_handler = AcmeFileHandler()
    observer = Observer()
    observer.schedule(event_handler, path=ACME_JSON_PATH, recursive=False)
    observer.start()
    try:
        observer.join()
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

# Flask routes
@app.route("/")
def home():
    return Response("", status=200)

@app.route("/dot-status")
def dot_status():
    cert_ok = verify_cert()
    dot_ok = test_dot_resolution()

    status = {
        "certificate_valid": cert_ok,
        "dns_over_tls_functional": dot_ok
#        ,"details": {
#            "domain": DOMAIN,
#            "ip": IP_ADDRESS,
#            "resolver": RESOLVER
#        }
    }
    return jsonify(status), 200 if cert_ok and dot_ok else 500

# Main execution
if __name__ == "__main__":
    check_required_env_vars()
    update_certs()
    verify_cert()

    # Start Flask in a separate thread
    flask_thread = threading.Thread(target=lambda: app.run(host="0.0.0.0", port=80))
    flask_thread.start()

    # Start watching the acme.json file
    watch_acme_file()
