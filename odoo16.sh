#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found. Installing..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
else
    echo "Docker is already installed."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose not found. Installing..."
    sudo apt update
    sudo apt install -y curl
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose is already installed."
fi

# Display the installed Docker Compose version
docker-compose --version

# Get the directory where the script is being executed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the path for additional modules
ADDITIONAL_MODULES_PATH="${SCRIPT_DIR}/addons"

# Create the addons directory if it does not exist
mkdir -p "${ADDITIONAL_MODULES_PATH}"

# Pull Docker images
echo "Pulling the Odoo 16.0 image..."
docker pull odoo:16.0

echo "Pulling the PostgreSQL 13 image..."
docker pull postgres:13

# Start the PostgreSQL container
echo "Starting the PostgreSQL container..."
docker run -d \
    -e POSTGRES_USER=odoo \
    -e POSTGRES_PASSWORD=odoo \
    -e POSTGRES_DB=postgres \
    --name meu_db \
    postgres:13

# Wait a few seconds to ensure PostgreSQL is ready
echo "Waiting for PostgreSQL to initialize..."
sleep 10

# Check if netstat is installed
if ! command -v netstat &> /dev/null
then
    echo "Netstat not found. Installing..."
    sudo apt update
    sudo apt install -y net-tools
else
    echo "Netstat is already installed."
fi

# Function to check if a port is available
is_port_free() {
    # Check if the port is not in use
    ! netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".*:'$1'$"' | grep -q "$1"
}

# Set the initial port
PORT=8069

# Check if the port is available, if not, try the next one
while ! is_port_free $PORT; do
    echo "Port $PORT is in use, trying the next one..."
    PORT=$((PORT + 1))
done

# Start the Odoo container
echo "Starting the Odoo container on port $PORT..."
docker run -d \
    -p $PORT:8069 \
    -v ${ADDITIONAL_MODULES_PATH}:/mnt/extra-addons \
    --name meu_odoo \
    --link meu_db:db \
    odoo:16.0

echo "Done! Odoo should be available at http://localhost:$PORT"
