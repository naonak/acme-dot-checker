FROM python:3.13-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl openssl knot-dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY main.py main.py
COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 80

CMD ["python", "main.py"]
