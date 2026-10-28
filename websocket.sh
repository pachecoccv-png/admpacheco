
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[+] Instalando Servidor WebSocket WS-EPro (Puerto 80)...${NC}"

ufw allow 80/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1 || true
iptables-save >/dev/null 2>&1 || true

apt-get install python3 -y >/dev/null 2>&1

cat << 'EOF' > /usr/local/bin/ws.py
import socket, threading, select

LISTEN_PORT = 80
SSH_PORT = 22
BUFLEN = 4096

class Proxy(threading.Thread):
    def __init__(self, client, address):
        threading.Thread.__init__(self)
        self.client = client
        self.address = address

    def run(self):
        try:
            target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target.connect(('127.0.0.1', SSH_PORT))
            self.client.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
            sockets = [self.client, target]
            while True:
                out, _, _ = select.select(sockets, [], [])
                if self.client in out:
                    data = self.client.recv(BUFLEN)
                    if not data: break
                    target.sendall(data)
                if target in out:
                    data = target.recv(BUFLEN)
                    if not data: break
                    self.client.sendall(data)
        except:
            pass
        finally:
            self.client.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', LISTEN_PORT))
    server.listen(100)
    while True:
        client, addr = server.accept()
        Proxy(client, addr).start()

if __name__ == '__main__':
    main()
EOF

cat << 'EOF' > /etc/systemd/system/ws-epro.service
[Unit]
Description=WebSocket Proxy Service ADMPacheco
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws-epro >/dev/null 2>&1
systemctl restart ws-epro

if systemctl is-active --quiet ws-epro; then
    echo -e "${GREEN}[✓] WebSocket WS-EPro ACTIVO en puerto 80 -> SSH 22.${NC}"
else
    echo -e "${RED}[!] Error al iniciar WebSocket.${NC}"
fi
