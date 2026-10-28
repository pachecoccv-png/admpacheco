
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Instalando Stunnel4 y generando Certificados SSL...${NC}"

ufw allow 443/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 443 -j ACCEPT >/dev/null 2>&1 || true
iptables-save >/dev/null 2>&1 || true

apt-get update -y >/dev/null 2>&1
apt-get install stunnel4 openssl -y >/dev/null 2>&1

openssl req -new -x509 -days 365 -nodes -config <(cat <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
[dn]
C = BR
ST = SP
L = S
O = ADMPacheco
OU = SSL
CN = vps.admpacheco.com
EOF
) -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem >/dev/null 2>&1

cat << 'EOF' > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[ssh]
accept = 443
connect = 127.0.0.1:22
EOF

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel 2>/dev/null

if systemctl is-active --quiet stunnel4 || systemctl is-active --quiet stunnel; then
    echo -e "${GREEN}[✓] Stunnel SSL ACTIVO en puerto 443 -> SSH 22.${NC}"
else
    echo -e "${RED}[!] Error al iniciar Stunnel SSL.${NC}"
fi
