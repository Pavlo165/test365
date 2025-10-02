#!/bin/bash

BRANCH=$1
DOMAIN=$2

# --- Function to check and install dependencies ---
install_dependencies() {
  echo "Checking dependencies..."

  # Check for Nginx
  if ! command -v nginx &> /dev/null; then
    echo "Nginx not found. Installing Nginx..."
    sudo apt-get update
    sudo apt-get install -y nginx
  else
    echo "Nginx is already installed."
  fi

  # Check for Docker
  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
  else
    echo "Docker is already installed."
  fi

  # Check for Docker Compose
  if ! command -v docker compose &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
  else
    echo "Docker Compose is already installed."
  fi

  echo "All dependencies are satisfied."
}

check_prerequisites() {
  echo "Checking for prerequisites (certificates and auth file)..."

  local CERT_FILE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
  local KEY_FILE="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
  local AUTH_FILE="/etc/nginx/.htpasswd"

  # Check for SSL certificate files
  if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Error: SSL certificate files not found for $DOMAIN."
    echo "Please run Certbot to generate them first"
    exit 1
  fi

  # Check for Basic Auth password file
  if [ ! -f "$AUTH_FILE" ]; then
    echo "Error: Basic Auth password file not found at $AUTH_FILE."
    echo "Please create it using 'htpasswd"
    exit 1
  fi

  echo "Prerequisites check passed."
}

setup_nginx() {
  echo "Setting up Nginx configuration for $DOMAIN from template..."

  local TEMPLATE_PATH="../template/nginx.conf.template"
  local NGINX_CONF_PATH="/etc/nginx/sites-available/$DOMAIN.conf"

  if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Error: Nginx template file not found at $TEMPLATE_PATH"
    exit 1
  fi

  sed "s/__DOMAIN__/$DOMAIN/g; s/__HOST_PORT__/$HOST_PORT/g" "$TEMPLATE_PATH" | sudo tee "$NGINX_CONF_PATH" > /dev/null

  echo "Nginx config created at $NGINX_CONF_PATH"

  sudo ln -sf "$NGINX_CONF_PATH" "/etc/nginx/sites-enabled/"

  if sudo nginx -t; then
    echo "Nginx configuration is OK. Reloading Nginx..."
    sudo systemctl reload nginx
  else
    echo "Error in Nginx configuration. Please check manually."
    exit 1
  fi
}

run_post_deploy_checks() {
  echo "--- Running Post-Deployment Checks ---"

  echo "Waiting 5 seconds for the application to start..."
  sleep 5

  echo "1. Checking HTTPS availability for https://$DOMAIN..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN")

  if [ "$HTTP_STATUS" = "401" ]; then
    echo "Success: Site is available and protected (Status code: $HTTP_STATUS)."
  elif [ "$HTTP_STATUS" = "200" ]; then
    echo "Success: Site is available (Status code: $HTTP_STATUS)."
  else
    echo "Error: Site is not available or returned an unexpected status code: $HTTP_STATUS."
    exit 1
  fi

  echo "2. Checking SSL certificate expiration..."
  EXPIRY_DATE=$(openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d'=' -f2)

  if [ -n "$EXPIRY_DATE" ]; then
    echo "Success: Certificate is valid."
    echo "xpires on: $EXPIRY_DATE"

    if date --version >/dev/null 2>&1 && [[ "$(date --version)" == *"GNU"* ]]; then
        EXPIRY_SECONDS=$(date -d "$EXPIRY_DATE" +%s)
        NOW_SECONDS=$(date +%s)
        DAYS_LEFT=$(((EXPIRY_SECONDS - NOW_SECONDS) / 86400))
        echo "Days left: $DAYS_LEFT"
    fi
  else
    echo "Error: Could not retrieve certificate information."
    exit 1
  fi
}

# --- Parameter Validation ---
if [ -z "$BRANCH" ] || [ -z "$DOMAIN" ]; then
  echo "Error: Branch and domain must be specified."
  echo "Usage: $0 <branch> <domain>"
  exit 1
fi


# --- Run dependency check ---
install_dependencies

echo "Proceeding with deployment..."

HOST_PORT=3002
APP_COLOR=""

if [ "$BRANCH" == "main" ]; then
  APP_COLOR="purple"
else
  # Assuming any other branch is for development
  APP_COLOR="green"
fi

PROJECT_NAME="app-${BRANCH}"

echo "Using project name: $PROJECT_NAME"

APP_COLOR=$APP_COLOR HOST_PORT=$HOST_PORT docker compose -p $PROJECT_NAME up -d --build

# Check for certificates and auth file
check_prerequisites

# Setup Nginx
setup_nginx

# Run Post-Deployment Checks
run_post_deploy_checks

echo "--- Deployment finished successfully! ---"