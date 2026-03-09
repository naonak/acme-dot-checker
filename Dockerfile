FROM python:3.14-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl openssl knot-dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r -g 1000 appuser && useradd -r -u 1000 -g appuser appuser

WORKDIR /app

COPY main.py main.py
COPY gunicorn.conf.py gunicorn.conf.py
COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/certs /app/data && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 80

CMD ["gunicorn", "-c", "gunicorn.conf.py", "main:app"]
