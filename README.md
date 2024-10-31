# ACME Certificate Extractor and DNS-over-TLS Health Checker

This project is a Flask-based service that extracts SSL certificates from a Traefik `acme.json` file and converts them into `.pem` files usable for DNS-over-TLS (DoT) encryption in AdGuard. It also provides a health-check API for monitoring the validity of the SSL certificate and the functionality of DNS-over-TLS resolution. The script also monitors acme.json for changes and updates certificates accordingly.

## Features

- **Extract and Generate Certificates**: Reads the `acme.json` file from Traefik and creates `fullchain.pem` and `privkey.pem` files for use in AdGuard or other DoT services.
- **Certificate Change Detection**: Automatically updates the certificate files if changes are detected in `acme.json`.
- **DNS-over-TLS Health Check**: Tests the SSL certificate and checks DNS-over-TLS resolution using `kdig`.
- **REST API**: Exposes an API to verify the health of the certificate and DNS-over-TLS functionality.

## Prerequisites

- **Python** 3.6 or higher
- **Docker** and **Docker Compose**
- **Traefik** configured for SSL certificate generation

## Installation and Usage

### Running Locally

1. Clone this repository:
   ```bash
   git clone https://github.com/username/acme-dot-checker.git
   cd acme-dot-checker
   ```

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set environment variables:
   ```bash
   export DOMAIN="your-domain.com"
   export IP_ADDRESS="your-ip-address"
   export RESOLVER="letsencrypt"
   export VERBOSITY="INFO"
   ```

4. Run the Python script:
   ```bash
   python main.py
   ```

### Using Docker Compose

You can deploy this service using Docker Compose with the following configuration:

```yaml
version: '3.8'

services:
  acme-dot-checker:
    image: ghcr.io/username/acme-dot-checker:main
    container_name: acme-dot-checker
    restart: unless-stopped
    networks:
      - traefik-net
    volumes:
      - /path/to/acme.json:/app/data/acme.json:ro
      - /path/to/certs:/app/certs:rw
    environment:
      - DOMAIN=your-domain.com
      - IP_ADDRESS=traefik-ip-address
      - RESOLVER=letsencrypt
      - VERBOSITY=INFO
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-net"
      - "traefik.http.services.acme-dot-checker.loadbalancer.server.port=80"
      - "traefik.http.routers.acme-dot-checker.rule=Host(`your-domain.com`)"
      - "traefik.http.routers.acme-dot-checker.entrypoints=websecure"
      - "traefik.http.routers.acme-dot-checker.tls=true"
      - "traefik.http.routers.acme-dot-checker.tls.certresolver=letsencrypt"

networks:
  traefik-net:
    external: true
```

### Explanation of the Docker Compose Configuration

- **Volumes**: 
  - `/path/to/certs`: Directory for outputting `fullchain.pem` and `privkey.pem` files.
  - `/path/to/acme.json`: Path to Traefik's `acme.json` file for reading certificates.
- **Environment Variables**: 
  - `DOMAIN`: The domain for the SSL certificate.
  - `IP_ADDRESS`: The IP address of the domain.
  - `RESOLVER`: The ACME resolver used (e.g., `letsencrypt`).
  - `VERBOSITY`: Logging level (default: `INFO`).

## API Endpoints

- **GET /**: A simple health check to confirm the service is running (returns status 200).
- **GET /dot-status**: Checks the validity of the SSL certificate and the functionality of DNS-over-TLS resolution. Returns a JSON response indicating the status.

## Example Usage

- **Certificate Extraction**: The service automatically extracts certificates from `acme.json` and writes them to `fullchain.pem` and `privkey.pem` in the specified directory.
- **Health Check**: Use the `/dot-status` endpoint to verify the certificate and DNS-over-TLS health, ensuring your DoT setup is secure and functional.

## Contributing

Contributions are welcome! If you'd like to suggest improvements, open issues, or submit pull requests, feel free to contribute.

## License

This project is licensed under the MIT License.
