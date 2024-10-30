#!/bin/bash

# Définir les valeurs d'environnement par défaut si elles ne sont pas déjà définies
: "${CERT_DIR:=/certs}"
: "${CERT_PATH:=$CERT_DIR/fullchain.pem}"
: "${KEY_PATH:=$CERT_DIR/privkey.pem}"
: "${ACME_JSON_PATH:=/etc/ssl-resolver/acme.json}"
: "${IP_ADDRESS:=127.0.0.1}"
: "${RESOLVER:=letsencrypt}"
: "${VERBOSITY:=INFO}"

# Vérifier que toutes les variables d'environnement requises sont définies
check_required_env_vars() {
  local missing_env_vars=()
  for var in DOMAIN RESOLVER; do
    if [[ -z "${!var}" ]]; then
      missing_env_vars+=("$var")
    fi
  done
  if [[ ${#missing_env_vars[@]} -gt 0 ]]; then
    echo "Erreur : Les variables d'environnement suivantes sont manquantes : ${missing_env_vars[*]}"
    exit 1
  fi
}
check_required_env_vars

# Fonction de logging
log() {
  local level="$1"
  shift
  local message="$@"
  declare -A levels=(["DEBUG"]=0 ["INFO"]=1 ["WARNING"]=2 ["ERROR"]=3)
  if [[ ${levels[$level]} -ge ${levels[$VERBOSITY]} ]]; then
    echo "[$level] $message"
  fi
}

# Vérifier la présence des outils nécessaires
if ! command -v jq &> /dev/null || ! command -v openssl &> /dev/null || ! command -v curl &> /dev/null; then
    log "ERROR" "Certains outils requis (jq, openssl, curl) ne sont pas installés."
    exit 1
fi

# Création du répertoire de certificats si inexistant
mkdir -p "${CERT_DIR}"

# Fonction pour extraire les certificats de Traefik via acme.json
function update_certs {
  if [[ -f "$ACME_JSON_PATH" ]]; then
    log "INFO" "Extraction des certificats depuis acme.json pour le résolveur '$RESOLVER'..."

    # Effacer le contenu des fichiers avant chaque mise à jour
    > "$CERT_PATH"
    > "$KEY_PATH"

    # Extraction du certificat et de la clé en fonction du résolveur
    CERT_BASE64=$(jq -r --arg DOMAIN "$DOMAIN" --arg RESOLVER "$RESOLVER" '.[$RESOLVER].Certificates[] | select(.domain.main==$DOMAIN) | .certificate // empty' "$ACME_JSON_PATH")
    KEY_BASE64=$(jq -r --arg DOMAIN "$DOMAIN" --arg RESOLVER "$RESOLVER" '.[$RESOLVER].Certificates[] | select(.domain.main==$DOMAIN) | .key // empty' "$ACME_JSON_PATH")

    if [[ -n "$CERT_BASE64" && -n "$KEY_BASE64" ]]; then
      echo "$CERT_BASE64" | base64 -d > "$CERT_PATH"
      echo "$KEY_BASE64" | base64 -d > "$KEY_PATH"

      # Appliquer les permissions 600 aux certificats
      chmod 600 "$CERT_PATH" "$KEY_PATH"
      log "INFO" "Certificat et clé extraits avec succès pour le résolveur '$RESOLVER', et permissions 600 appliquées."
    else
      log "WARNING" "Certificat ou clé manquant dans acme.json pour le résolveur '$RESOLVER'. Tentative de régénération via Traefik..."
      force_update
      update_certs
    fi
  else
    log "ERROR" "Fichier acme.json introuvable."
    exit 1
  fi
}

# Fonction pour vérifier la validité du certificat
function verify_cert {
  log "INFO" "Vérification du certificat actuel pour $DOMAIN..."
  EXPIRATION_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$IP_ADDRESS:443" 2>/dev/null \
    | openssl x509 -noout -dates | grep "notAfter" | cut -d'=' -f2)

  if [[ -n "$EXPIRATION_DATE" ]]; then
    log "INFO" "Le certificat est valide jusqu'au : $EXPIRATION_DATE"
    return 0
  else
    log "WARNING" "Le certificat est invalide ou a expiré."
    return 1
  fi
}

# Fonction pour forcer la mise à jour du certificat via curl et attendre
function force_update {
  log "INFO" "Forçage de la mise à jour du certificat via Traefik..."
  curl -s -o /dev/null --resolve "$DOMAIN:443:$IP_ADDRESS" "$CURL_URL"
  log "DEBUG" "Attente de quelques secondes pour que Traefik mette à jour le certificat..."
  sleep 10
}

# Exécution du script
update_certs
verify_cert
if [[ $? -ne 0 ]]; then
  force_update
  update_certs
  verify_cert
  if [[ $? -eq 0 ]]; then
    log "INFO" "Le certificat a été mis à jour avec succès."
  else
    log "ERROR" "Échec de la mise à jour du certificat."
  fi
else
  log "INFO" "Le certificat est déjà valide."
fi
