# Utiliser une image légère de base
FROM debian:latest

# Installer les dépendances
RUN apt-get update && apt-get install -y \
    jq \
    openssl \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Créer le répertoire de certificats
RUN mkdir -p /certs

# Copier le script d'extraction dans l'image
COPY extract_certs.sh /usr/local/bin/extract_certs.sh

# Donner les permissions d'exécution au script
RUN chmod +x /usr/local/bin/extract_certs.sh

# Définir le point d'entrée
ENTRYPOINT ["/usr/local/bin/extract_certs.sh"]
