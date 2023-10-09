#!/bin/bash

# Solicita o nome do projeto ao usuário
read -p "Enter the project name: " PROJECT_NAME

# Pergunta se deve criar um repositório no GitHub
read -p "Create a private GitHub repository for the project? (y/n): " CREATE_GITHUB_REPO

# Define o diretório do script e o caminho para os módulos adicionais
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDITIONAL_MODULES_PATH="${SCRIPT_DIR}/${PROJECT_NAME}/addons"

# Cria o diretório para módulos adicionais se ele não existir
mkdir -p "${ADDITIONAL_MODULES_PATH}"

# Verifica e instala o Docker se necessário
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

# Verifica e instala o Docker Compose se necessário
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose not found. Installing..."
    sudo apt install -y curl
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose is already installed."
fi

# Exibe a versão do Docker Compose instalada
docker-compose --version

# Baixa as imagens Docker necessárias
echo "Pulling the Odoo 16.0 image..."
docker pull odoo:16.0

echo "Pulling the PostgreSQL 13 image..."
docker pull postgres:13

# Verifica se já existe um container PostgreSQL rodando com o nome do projeto
if [ "$(docker ps -q -f name=${PROJECT_NAME}_db)" ]; then
    echo "A PostgreSQL container named ${PROJECT_NAME}_db is already running. Skipping the database setup..."
else
    echo "Starting the PostgreSQL container named ${PROJECT_NAME}_db..."
    docker run -d \
        -e POSTGRES_USER=odoo \
        -e POSTGRES_PASSWORD=odoo \
        -e POSTGRES_DB=postgres \
        --name ${PROJECT_NAME}_db \
        postgres:13
    
    echo "Waiting for PostgreSQL to initialize..."
    sleep 10
fi

# Verifica e instala o netstat se necessário
if ! command -v netstat &> /dev/null
then
    echo "Netstat not found. Installing..."
    sudo apt update
    sudo apt install -y net-tools
else
    echo "Netstat is already installed."
fi

# Função para verificar se uma porta está disponível
is_port_free() {
    ! netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".*:'$1'$"' | grep -q "$1"
}

# Define a porta inicial
PORT=8069

# Verifica se a porta está disponível, se não, tenta a próxima
while ! is_port_free $PORT; do
    echo "Port $PORT is in use, trying the next one..."
    PORT=$((PORT + 1))
done

# Configura o Odoo para ouvir em todos os endereços IP
ODDO_CONFIG_PATH="${SCRIPT_DIR}/${PROJECT_NAME}/odoo.conf"
echo "[options]" > "$ODDO_CONFIG_PATH"
echo "xmlrpc_interface = 0.0.0.0" >> "$ODDO_CONFIG_PATH"

# Inicia o container Odoo
echo "Starting the Odoo container named ${PROJECT_NAME}_odoo on port $PORT..."
docker run -d \
    -p $PORT:8069 \
    -v ${ADDITIONAL_MODULES_PATH}:/mnt/extra-addons \
    -v ${ODDO_CONFIG_PATH}:/etc/odoo/odoo.conf \
    --name ${PROJECT_NAME}_odoo \
    --link ${PROJECT_NAME}_db:db \
    odoo:16.0

# Cria um repositório privado no GitHub, se selecionado
if [[ $CREATE_GITHUB_REPO == "y" || $CREATE_GITHUB_REPO == "Y" ]]; then
    # Você precisará configurar as credenciais do GitHub aqui
    GITHUB_USERNAME="seu_nome_de_usuário"
    GITHUB_TOKEN="seu_token_de_acesso_pessoal"

    # Crie um repositório privado no GitHub com o nome "odoo-PROJECT_NAME"
    curl -X POST -H "Authorization: token $GITHUB_TOKEN" -d '{"name": "'${PROJECT_NAME}'", "private": true}' https://api.github.com/user/repos

    # Configure o repositório Git local e faça o upload dos addons
    cd ${ADDITIONAL_MODULES_PATH}
    git init
    git add .
    git commit -m "Initial commit"
    git branch -M main
    git remote add origin https://github.com/${GITHUB_USERNAME}/odoo-${PROJECT_NAME}.git
    git push -u origin main
fi

echo "Done! Odoo should be available at http://localhost:$PORT"
