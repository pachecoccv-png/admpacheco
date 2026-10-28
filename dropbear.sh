#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Instalando Dropbear (Puerto 90)...${NC}"

ufw allow 90/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 90 -j ACCEPT >/dev/null 2>&1 || true
iptables-save >/dev/null 2>&1 || true

apt-get update -y >/dev/null 2>&1
apt-get install dropbear -y >/dev/null 2>&1
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear 2>/dev/null
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=90/g' /etc/default/dropbear 2>/dev/null
systemctl restart dropbear

if systemctl is-active --quiet dropbear; then
    echo -e "${GREEN}[✓] Dropbear instalado y activo en el puerto 90.${NC}"
else
    echo -e "${RED}[!] Error al iniciar Dropbear.${NC}"
fi
