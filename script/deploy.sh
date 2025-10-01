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

# --- Parameter Validation ---
if [ -z "$BRANCH" ] || [ -z "$DOMAIN" ]; then
  echo "Error: Branch and domain must be specified."
  echo "Usage: $0 <branch> <domain>"
  exit 1
fi


# --- Run dependency check ---
install_dependencies

# --- Main script logic continues here ---
echo "Proceeding with deployment..."