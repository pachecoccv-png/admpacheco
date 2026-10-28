
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Instalando y configurando Squid Proxy (Puerto 3128)...${NC}"

ufw allow 3128/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 3128 -j ACCEPT >/dev/null 2>&1 || true
iptables-save >/dev/null 2>&1 || true

apt-get update -y >/dev/null 2>&1
apt-get install squid -y >/dev/null 2>&1

cat << 'EOF' > /etc/squid/squid.conf
http_port 3128
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSH dst 127.0.0.1
acl payload dstdomain .com .br .net .gov .org
http_access allow localhost
http_access allow SSH
http_access allow payload
http_access allow all
visible_hostname ADMPacheco
EOF

systemctl restart squid >/dev/null 2>&1

if systemctl is-active --quiet squid; then
    echo -e "${GREEN}[✓] Squid Proxy ACTIVO y configurado en puerto 3128.${NC}"
else
    echo -e "${RED}[!] Error al iniciar Squid Proxy.${NC}"
fi
