
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Instalando y configurando UDP-Custom (Puerto 36712)...${NC}"

ufw allow 36712/udp >/dev/null 2>&1 || true
iptables -I INPUT -p udp --dport 36712 -j ACCEPT >/dev/null 2>&1 || true
iptables-save >/dev/null 2>&1 || true

mkdir -p /root/udp
wget -O /root/udp/udp-custom "https://raw.githubusercontent.com/AnonymouSX-x/UDP-Custom/main/udp-custom" >/dev/null 2>&1
chmod +x /root/udp/udp-custom

echo '{"listen": ":36712", "stream_buffer": 16777216, "receive_buffer": 16777216, "auth": {"mode": "pass"}}' > /root/udp/config.json

cat << 'EOF' > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom Service
After=network.target

[Service]
User=root
Type=simple
WorkingDirectory=/root/udp/
ExecStart=/root/udp/udp-custom server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom >/dev/null 2>&1
systemctl restart udp-custom

if systemctl is-active --quiet udp-custom; then
    echo -e "${GREEN}[✓] UDP-Custom ACTIVO en el puerto 36712.${NC}"
else
    echo -e "${RED}[!] Error al iniciar el servicio UDP-Custom.${NC}"
fi
