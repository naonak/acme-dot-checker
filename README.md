# ACME Certificate Extractor and DNS-over-TLS Health Checker

This project is a Python service (Flask + gunicorn) that extracts SSL certificates from a Traefik `acme.json` file and converts them into `.pem` files usable for DNS-over-TLS (DoT) encryption in AdGuard. It also provides a health-check API for monitoring the validity of the SSL certificate and the functionality of DNS-over-TLS resolution. The service monitors `acme.json` for changes and updates certificates accordingly.

## Features

- **Extract and Generate Certificates**: Reads the `acme.json` file from Traefik and creates `fullchain.pem` and `privkey.pem` files for use in AdGuard or other DoT services.
- **Certificate Change Detection**: Automatically updates the certificate files if changes are detected in `acme.json`.
- **DNS-over-TLS Health Check**: Tests the SSL certificate and checks DNS-over-TLS resolution using `kdig`.
- **REST API**: Exposes an API to verify the health of the certificate and DNS-over-TLS functionality, with built-in caching (60s TTL) to avoid excessive subprocess calls.
- **Production-ready**: Runs on [gunicorn](https://gunicorn.org/) with a non-root user inside Docker.

## Prerequisites

- **Docker** and **Docker Compose**
- **Traefik** configured for SSL certificate generation

## Installation and Usage

### Using Docker Compose

```yaml
services:
  acme-dot-checker:
    image: ghcr.io/naonak/acme-dot-checker:main
    container_name: acme-dot-checker
    restart: unless-stopped
    user: "1000:1000"
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

> **Note:** The container runs as `uid=1000`. Make sure the mounted volumes (`acme.json` and the certs directory) are readable/writable by this UID on the host, or adjust `user:` accordingly.

### Running Locally

```bash
git clone https://github.com/naonak/acme-dot-checker.git
cd acme-dot-checker
pip install -r requirements.txt
export DOMAIN="your-domain.com"
export IP_ADDRESS="your-ip-address"
python main.py
```

## Environment Variables

| Variable          | Default                | Description                                          |
|-------------------|------------------------|------------------------------------------------------|
| `DOMAIN`          | *(required)*           | Domain for the SSL certificate                       |
| `IP_ADDRESS`      | `127.0.0.1`            | IP address used to verify the certificate            |
| `RESOLVER`        | `letsencrypt`          | ACME resolver name in `acme.json`                    |
| `CERT_DIR`        | `/app/certs`           | Output directory for `.pem` files                    |
| `ACME_JSON_PATH`  | `/app/data/acme.json`  | Path to Traefik's `acme.json`                        |
| `VERBOSITY`       | `INFO`                 | Logging level (`DEBUG`, `INFO`, `WARNING`, `ERROR`)  |

## API Endpoints

### `GET /`
Simple liveness check. Returns `200`.

### `GET /dot-status`
Checks SSL certificate validity and DNS-over-TLS resolution. Results are cached for 60 seconds.

**Response headers:**
- `Cache-Control: max-age=60`
- `Age: <seconds since last check>`

**Response body:**
```json
{
  "certificate_valid": true,
  "dns_over_tls_functional": true,
  "cached": true,
  "retry_in": 42
}
```

Returns `200` if both checks pass, `500` otherwise.

## License

This project is licensed under the MIT License.
