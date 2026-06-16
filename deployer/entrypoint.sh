#!/bin/bash
# filepath: deployer/entrypoint.sh
set -e

echo "=== Pangolin Deployer ==="
echo "Generating configuration files from environment variables..."

# ============================================
# DEFAULT VALUES
# ============================================
GERBIL_START_PORT=${GERBIL_START_PORT:-51820}
LOG_LEVEL=${LOG_LEVEL:-info}
ORG_BLOCK_SIZE=${ORG_BLOCK_SIZE:-24}
ORG_SUBNET_GROUP=${ORG_SUBNET_GROUP:-100.90.128.0/20}
ENABLE_IPV6=${ENABLE_IPV6:-true}
ENABLE_GEOBLOCKING=${ENABLE_GEOBLOCKING:-false}
INSTALL_GERBIL=${INSTALL_GERBIL:-true}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-docker}
EMAIL_ENABLED=${EMAIL_ENABLED:-false}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT:-587}

# Set GERBIL_BASE_ENDPOINT after DOMAIN is validated
GERBIL_BASE_ENDPOINT=${GERBIL_BASE_ENDPOINT:-pangolin.${DOMAIN}}

# Auto-generate server secret if not provided
if [ -z "${SERVER_SECRET}" ]; then
  echo "No SERVER_SECRET provided — generating a random secret."
  SERVER_SECRET=$(openssl rand -base64 32)
  export SERVER_SECRET
fi

# ============================================
# DIRECTORY STRUCTURE
# ============================================
echo "Creating directory structure..."

mkdir -p /config/db
mkdir -p /config/traefik/dynamic
mkdir -p /config/traefik/logs
mkdir -p /config/letsencrypt
mkdir -p /config/postgres

# ============================================
# Copy templates into /config and expand variables
# ============================================
echo "Copying template files into /config..."
TEMPLATES_DIR=/app/templates

if [ -d "$TEMPLATES_DIR" ]; then
  if [ -f "$TEMPLATES_DIR/config.yml.template" ]; then
    cp "$TEMPLATES_DIR/config.yml.template" /config/config.yml
  else
    echo "Warning: missing $TEMPLATES_DIR/config.yml.template"
  fi

  if [ -f "$TEMPLATES_DIR/traefik_config.yml.template" ]; then
    cp "$TEMPLATES_DIR/traefik_config.yml.template" /config/traefik/traefik_config.yml
  else
    echo "Warning: missing $TEMPLATES_DIR/traefik_config.yml.template"
  fi

  if [ -f "$TEMPLATES_DIR/dynamic_config.yml.template" ]; then
    cp "$TEMPLATES_DIR/dynamic_config.yml.template" /config/traefik/dynamic_config.yml
  else
    echo "Warning: missing $TEMPLATES_DIR/dynamic_config.yml.template"
  fi
else
  echo "Warning: templates directory $TEMPLATES_DIR not found; templates will not be copied."
fi

# Expand variables in the copied templates
if command -v envsubst >/dev/null 2>&1; then
  echo "Expanding templates with envsubst..."
  for f in /config/config.yml /config/traefik/traefik_config.yml /config/traefik/dynamic_config.yml; do
    if [ -f "$f" ]; then
      envsubst < "$f" > "${f}.resolved" && mv "${f}.resolved" "$f"
    fi
  done
else
  echo "envsubst not found — leaving templates as-is (sed fallback not implemented for copied templates)."
fi

# ============================================
# HANDLE CERTIFICATE FILES
# ============================================
echo "Handling certificate files..."

if [ -n "${SSL_CERTIFICATE}" ] && [ "${SSL_CERTIFICATE}" != "skip" ]; then
    echo "Decoding SSL certificate..."
    echo "${SSL_CERTIFICATE}" | base64 -d > /config/letsencrypt/fullchain.pem
fi

if [ -n "${SSL_PRIVATE_KEY}" ] && [ "${SSL_PRIVATE_KEY}" != "skip" ]; then
    echo "Decoding SSL private key..."
    echo "${SSL_PRIVATE_KEY}" | base64 -d > /config/letsencrypt/privkey.pem
fi

# ============================================
# HANDLE POSTGRES CONNECTION
# ============================================
if [ -n "${POSTGRES_CONNECTION_STRING}" ]; then
    echo "Configuring external PostgreSQL..."
    echo "${POSTGRES_CONNECTION_STRING}" > /config/postgres/connection.txt
fi

# ============================================
# VERIFY REQUIRED VARIABLES
# ============================================
echo "Verifying required configuration..."

if [ -z "${DOMAIN}" ]; then
    echo "ERROR: DOMAIN is required but not set"
    exit 1
fi

if [ -z "${DASHBOARD_URL}" ]; then
    echo "ERROR: DASHBOARD_URL is required but not set"
    exit 1
fi

if [ -z "${LETSENCRYPT_EMAIL}" ]; then
    echo "WARNING: LETSENCRYPT_EMAIL is not set - SSL certificates may not work"
fi

# ============================================
# SUMMARY
# ============================================
echo ""
echo "=== Configuration Complete ==="
echo "Generated files:"
ls -la /config/
ls -la /config/traefik/
ls -la /config/traefik/dynamic/
ls -la /config/letsencrypt/ 2>/dev/null || true

echo ""
echo "Deployer completed successfully!"
echo "Other containers can now start..."

exit 0