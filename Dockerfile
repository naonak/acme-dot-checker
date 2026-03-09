FROM python:3.14-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl openssl knot-dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
RUN groupadd -r -g ${GID} appuser && useradd -r -u ${UID} -g appuser appuser

WORKDIR /app

COPY main.py main.py
COPY gunicorn.conf.py gunicorn.conf.py
COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/certs /app/data && \
    chown -R appuser:appuser /app && \
    mkdir -p /tmp && chmod 1777 /tmp

USER appuser

EXPOSE 80

CMD ["gunicorn", "-c", "gunicorn.conf.py", "main:app"]
