#!/bin/bash

# Atualiza o sistema e instala os pacotes necessários
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3-pip build-essential wget python3-dev python3-venv \
    libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libtiff5-dev libjpeg8-dev \
    libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev libharfbuzz-dev \
    libfribidi-dev libxcb1-dev libpq-dev

# Cria um usuário específico para o Odoo
sudo useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

# Instala o PostgreSQL e cria o usuário do banco de dados
sudo apt install -y postgresql
sudo su - postgres -c "createuser -s odoo"

# Muda para o diretório do usuário Odoo e baixa o Odoo da branch oficial
sudo su - odoo -c "git clone https://github.com/odoo/odoo.git --depth 1 --branch 16.0 /opt/odoo/odoo16"

# Configura o ambiente virtual Python para o Odoo
sudo su - odoo -c "python3 -m venv /opt/odoo/odoo-venv"
sudo su - odoo -c "/opt/odoo/odoo-venv/bin/pip install wheel"
sudo su - odoo -c "/opt/odoo/odoo-venv/bin/pip install -r /opt/odoo/odoo16/requirements.txt"

# Cria o diretório para os arquivos adicionais e de log
sudo mkdir /var/log/odoo && sudo chown odoo: /var/log/odoo
sudo mkdir /opt/odoo/odoo-custom-addons && sudo chown odoo: /opt/odoo/odoo-custom-addons

# Cria um arquivo de configuração para o Odoo
cat <<EOF | sudo tee /etc/odoo16.conf
[options]
; This is the password that allows database operations:
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo16/addons,/opt/odoo/odoo-custom-addons
logfile = /var/log/odoo/odoo.log
EOF
sudo chown odoo: /etc/odoo16.conf

# Cria um serviço systemd para o Odoo
cat <<EOF | sudo tee /etc/systemd/system/odoo16.service
[Unit]
Description=Odoo16
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo16
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo16/odoo-bin -c /etc/odoo16.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

# Ativa e inicia o serviço
sudo systemctl daemon-reload
sudo systemctl enable --now odoo16.service

echo "Odoo 16 foi instalado e está rodando!"
