#!/bin/bash

# Verificar se o script está sendo executado como superusuário
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script deve ser executado como root" >&2
    exit 1
fi

echo "Atualizando repositórios..."
apt-get update

echo "Instalando bibliotecas Wayland..."
apt-get install -y libwayland-client0

echo "Baixando o pacote TeamViewer..."
wget -q https://download.teamviewer.com/download/linux/teamviewer_amd64.deb -O /tmp/teamviewer_amd64.deb

echo "Instalando TeamViewer..."
dpkg -i /tmp/teamviewer_amd64.deb

# Corrigir dependências quebradas, se houver
apt-get install -f

# Definir variáveis de ambiente para Wayland no perfil do usuário
echo "Configurando variáveis de ambiente para Wayland..."
echo "export QT_QPA_PLATFORM=wayland" >> /etc/profile

# Informar ao usuário para reiniciar a sessão
echo "Por favor, reinicie sua sessão de usuário para aplicar as configurações de ambiente."

# Opcional: Iniciar o TeamViewer automaticamente (remova o comentário abaixo se desejado)
# echo "Iniciando TeamViewer..."
# teamviewer

echo "Instalação e configuração completas."
