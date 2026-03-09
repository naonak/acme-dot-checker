#!/bin/bash
set -e

PUID=${PUID:-1000}
PGID=${PGID:-1000}

chown -R ${PUID}:${PGID} /app/certs

exec gosu ${PUID}:${PGID} "$@"
