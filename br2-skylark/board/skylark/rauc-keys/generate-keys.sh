#!/bin/sh
# Generate a self-signed DEVELOPMENT signing key for RAUC bundles.
# Production keys must not live in this repository.
set -eu
KEYDIR="$(cd "$(dirname "$0")" && pwd)"
openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
    -keyout "${KEYDIR}/development-1.key.pem" \
    -out "${KEYDIR}/development-1.cert.pem" \
    -subj "/O=Skylark/CN=Skylark Development Signing Key"
echo "Generated RAUC development key in ${KEYDIR}"
