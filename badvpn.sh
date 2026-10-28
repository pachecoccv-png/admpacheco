
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Instalando BadVPN UDPGW (Puerto 7300)...${NC}"

ufw allow 7300/udp >/dev/null 2>&1 || true
ufw allow 7300/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p udp --dport 7300 -j ACCEPT >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 7300 -j ACCEPT >/dev/null 2>&1 || true
iptables-save >/dev/null 2>&1 || true

wget -O /usr/local/bin/badvpn-udpgw "https://raw.githubusercontent.com/daynn3/badvpn-udpgw/master/badvpn-udpgw" >/dev/null 2>&1
chmod +x /usr/local/bin/badvpn-udpgw

cat << 'EOF' > /etc/systemd/system/bdr-udpgw.service
[Unit]
Description=Servicio BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bdr-udpgw >/dev/null 2>&1
systemctl restart bdr-udpgw

if systemctl is-active --quiet bdr-udpgw; then
    echo -e "${GREEN}[✓] BadVPN UDPGW activo en puerto 7300.${NC}"
else
    echo -e "${RED}[!] Error al iniciar BadVPN.${NC}"
fi
