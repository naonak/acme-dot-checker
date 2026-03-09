FROM python:3.14-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl openssl knot-dnsutils gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r -g 1000 appuser && useradd -r -u 1000 -g appuser appuser

WORKDIR /app

COPY main.py main.py
COPY gunicorn.conf.py gunicorn.conf.py
COPY requirements.txt requirements.txt
COPY entrypoint.sh /entrypoint.sh

RUN pip install --no-cache-dir -r requirements.txt && \
    mkdir -p /app/certs /app/data && \
    chown -R appuser:appuser /app && \
    mkdir -p /tmp && chmod 1777 /tmp && \
    chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gunicorn", "-c", "gunicorn.conf.py", "main:app"]
