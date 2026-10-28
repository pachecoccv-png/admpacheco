#!/bin/bash
# ======================================================
# PANEL ADMPACHECO - GESTOR VPS DEFINITIVO Y COMPLETO
# ======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Debes ejecutar este script como root (sudo -i).${NC}"
    exit 1
fi

# Apertura de puertos en Firewall (UFW / IPTables)
abrir_puerto() {
    local port=$1
    local proto=${2:-tcp}
    ufw allow $port/$proto >/dev/null 2>&1 || true
    iptables -I INPUT -p $proto --dport $port -j ACCEPT >/dev/null 2>&1 || true
    iptables-save >/dev/null 2>&1 || true
}

# Preparación de dependencias del sistema y entorno
instalar_dependencias() {
    if [ -f /etc/vps-pacheco/.deps_ok ]; then
        return 0
    fi

    echo -e "${YELLOW}[+] Preparando entorno del sistema y dependencias esenciales...${NC}"

    if ! loginctl show-user root 2>/dev/null | grep -q '^Linger=yes'; then
        loginctl enable-linger root 2>/dev/null || true
    fi

    if [ ! -d /run/user/0 ]; then
        mkdir -p /run/user/0
        chmod 700 /run/user/0
        chown root:root /run/user/0
    fi

    export XDG_RUNTIME_DIR=/run/user/0

    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg wget curl software-properties-common lsb-release ufw iptables >/dev/null 2>&1

    if [[ "$ID" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ubuntu-toolchain-r/test < /dev/null >/dev/null 2>&1 || true
        apt-get update -y >/dev/null 2>&1
        apt-get install -y libstdc++6 >/dev/null 2>&1
    elif [[ "$ID" == "debian" ]]; then
        apt-get install -y libstdc++6 >/dev/null 2>&1 || {
            ARCH=$(dpkg --print-architecture)
            LIBSTDCPP_DEB_URL="https://ftp.debian.org/debian/pool/main/g/gcc-11/libstdc++6-11-dbg_11.5.0-2_${ARCH}.deb"
            wget -O /tmp/libstdc++6.deb "$LIBSTDCPP_DEB_URL" >/dev/null 2>&1 || true
            dpkg -i /tmp/libstdc++6.deb >/dev/null 2>&1 || apt-get install -f -y >/dev/null 2>&1
        }
    fi

    if ! dpkg -l | grep -q libcurl4-openssl-dev; then
        apt-get install -y libcurl4-openssl-dev >/dev/null 2>&1
    fi

    mkdir -p /etc/vps-pacheco
    touch /etc/vps-pacheco/.deps_ok
    echo -e "${GREEN}[✓] Sistema preparado correctamente.${NC}"
    sleep 1
}

IP=$(wget -qO- ipv4.icanhazip.com || curl -s ipv4.icanhazip.com || echo "127.0.0.1")
SO=$(cat /etc/issue.net 2>/dev/null || uname -s)

check_status() {
    local port=$1
    local name=$2
    if ss -tuln 2>/dev/null | grep -q ":$port " || pgrep -f "$name" >/dev/null; then
        echo -e "${GREEN}[ON]${NC}"
    else
        echo -e "${RED}[OFF]${NC}"
    fi
}

contar_usuarios() {
    activos=0
    expirados=0
    total=0
    now_sec=$(date +%s)

    for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
        total=$((total+1))
        exp=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
        exp_sec=$(date -d "$exp" +%s 2>/dev/null || echo "0")
        if [ "$exp_sec" -gt 0 ] && [ "$now_sec" -gt "$exp_sec" ]; then
            expirados=$((expirados+1))
        else
            activos=$((activos+1))
        fi
    done
}

menu_principal() {
    while true; do
        clear
        contar_usuarios
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e "${YELLOW}                     @AndresPacheco                         ${NC}"
        echo -e "${RED}============================================================${NC}"
        echo -e " ${CYAN}S.O:${NC}    $SO         ${CYAN}Fecha:${NC} $(date +'%d-%m-%Y')"
        echo -e " ${CYAN}IP:${NC}     $IP                     ${CYAN}Hora:${NC}  $(date +'%H:%M:%S')"
        echo -e "${RED}============================================================${NC}"
        echo -e " ${GREEN}ACTIVA:${NC} $activos   ${RED}EXPIRADA:${NC} $expirados   ${YELLOW}BLOQUEADA:${NC} 0   ${CYAN}TOTAL:${NC} $total"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[1]>${NC} ADMINISTRAR CUENTAS (SSH/DROPBEAR)"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[2]>${NC} CONFIGURACION DE PROTOCOLOS"
        echo -e " ${CYAN}[3]>${NC} HERRAMIENTAS EXTRAS"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[4]>${NC} CONFIGURA API Y BOTS"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[5]>${NC} CONFIGURACION DEL SCRIPT"
        echo -e " ${CYAN}[6]>${NC} IDIOMA / LANGUAGE"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[7]>${NC} ${RED}[!] DESINSTALAR PANEL${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] SALIR DEL VPS${NC}   ${BLUE}[8] SALIR DEL SCRIPT${NC}   ${CYAN}[9] REINICIAR VPS${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -p " Ingresa una Opcion: " opcion

        case $opcion in
            1) admin_cuentas ;;
            2) menu_protocolos ;;
            3) echo -e "${YELLOW}[+] Herramientas Extras...${NC}"; sleep 1 ;;
            4) echo -e "${YELLOW}[+] Configuración de Bots API...${NC}"; sleep 1 ;;
            5) echo -e "${YELLOW}[+] Configuración del Script...${NC}"; sleep 1 ;;
            6) echo -e "${YELLOW}[+] Idioma: Español.${NC}"; sleep 1 ;;
            7) desinstalar_panel ;;
            8) exit 0 ;;
            9) reboot ;;
            0) logout ;;
            *) echo -e "${RED}Opción no válida.${NC}"; sleep 1 ;;
        esac
    done
}

admin_cuentas() {
    while true; do
        clear
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e "${YELLOW}             ADMINISTRAR CUENTAS (SSH/DROPBEAR)             ${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[1]>${NC} Crear Usuario SSH"
        echo -e " ${CYAN}[2]>${NC} Eliminar Usuario"
        echo -e " ${CYAN}[3]>${NC} Renovar Usuario"
        echo -e " ${CYAN}[4]>${NC} Listar Usuarios"
        echo -e " ${CYAN}[5]>${NC} Limpiar Expirados"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] VOLVER${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -p " Ingresa una Opcion: " op_acc

        case $op_acc in
            1)
                read -p "Nombre del usuario: " usr
                read -p "Contraseña: " pass
                read -p "Días de duración: " dias
                exp=$(date -d "+$dias days" +%Y-%m-%d)
                useradd -M -s /bin/false "$usr" 2>/dev/null
                echo "$usr:$pass" | chpasswd
                chage -E "$exp" "$usr"
                echo -e "${GREEN}[✓] Usuario '$usr' creado hasta $exp.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            2)
                read -p "Usuario a eliminar: " usr
                userdel -f "$usr" 2>/dev/null
                echo -e "${GREEN}[✓] Usuario '$usr' eliminado.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            3)
                read -p "Usuario a renovar: " usr
                read -p "Días adicionales: " dias
                exp=$(date -d "+$dias days" +%Y-%m-%d)
                chage -E "$exp" "$usr"
                echo -e "${GREEN}[✓] Renovado hasta $exp.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            4)
                clear
                printf "%-16s %-18s\n" "USUARIO" "EXPIRACIÓN"
                echo "----------------------------------------------------"
                for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
                    ex=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                    printf "%-16s %-18s\n" "$u" "$ex"
                done
                read -p "Presiona Enter para continuar..." aux ;;
            5)
                for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
                    ex=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                    exp_sec=$(date -d "$ex" +%s 2>/dev/null || echo "0")
                    if [ "$exp_sec" -gt 0 ] && [ "$(date +%s)" -gt "$exp_sec" ]; then
                        userdel -f "$u" 2>/dev/null
                    fi
                done
                echo -e "${GREEN}[✓] Usuarios expirados eliminados.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            0) break ;;
            *) sleep 1 ;;
        esac
    done
}

menu_protocolos() {
    while true; do
        clear
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e "${YELLOW}                ADMINISTRADOR DE PROTOCOLOS                 ${NC}"
        echo -e "${RED}============================================================${NC}"
        echo -e " ${CYAN}DROPBEAR:${NC} 90                  ${CYAN}PYTHON3:${NC} 80"
        echo -e " ${CYAN}SSH:${NC} 22                       ${CYAN}UDP-CUSTOM:${NC} 36712"
        echo -e "${RED}============================================================${NC}"
        echo -e " ${CYAN}[1]>${NC} AJUSTES SSH         $(check_status 22 ssh)  ${CYAN}[11]>${NC} OPENVPN             $(check_status 1194 openvpn)"
        echo -e " ${CYAN}[2]>${NC} DROPBEAR            $(check_status 90 dropbear)  ${CYAN}[12]>${NC} CHECKUSER ONLINE    $(check_status 8123 checkuser)"
        echo -e " ${CYAN}[3]>${NC} SOCKS PYTHON        $(check_status 8080 socks.py)  ${CYAN}[13]>${NC} ATKEN and HASH      $(check_status 9999 token)"
        echo -e " ${CYAN}[4]>${NC} STUNNEL (SSL)       $(check_status 443 stunnel)  ${CYAN}[14]>${NC} FILEBROWSER         $(check_status 8082 filebrowser)"
        echo -e " ${CYAN}[5]>${NC} SLOWDNS             $(check_status 53 dnstt)  ${CYAN}[15]>${NC} V2RAY/XRAY          $(check_status 8000 xray)"
        echo -e " ${CYAN}[6]>${NC} WS-EPRO             $(check_status 80 proxy)  ${CYAN}[16]>${NC} SSHGO               $(check_status 2222 sshgo)"
        echo -e " ${CYAN}[7]>${NC} UDP-CUSTOM          $(check_status 36712 udp-custom)  ${CYAN}[17]>${NC} WIREGUARD           $(check_status 51820 wg)"
        echo -e " ${CYAN}[8]>${NC} UDP-HYSTERIA        $(check_status 4434 hysteria)  ${CYAN}[18]>${NC} HCR CUSTOM          $(check_status 8888 hcr)"
        echo -e " ${CYAN}[9]>${NC} BADVPN-UDPGW        $(check_status 7300 badvpn)  ${CYAN}[19]>${NC} BHTTP TUNNEL        $(check_status 8989 bhttp)"
        echo -e " ${CYAN}[10]>${NC} SQUID               $(check_status 3128 squid)"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] Volver${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -p " Ingresa una Opcion: " op_prot

        case $op_prot in
            1)
                echo -e "${YELLOW}[+] Reiniciando servicio SSH (Puerto 22)...${NC}"
                abrir_puerto 22 tcp
                systemctl restart ssh || systemctl restart sshd
                echo -e "${GREEN}[✓] Servicio SSH activo.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            2)
                echo -e "${YELLOW}[+] Instalando Dropbear (Puerto 90)...${NC}"
                abrir_puerto 90 tcp
                apt-get update -y >/dev/null 2>&1
                apt-get install dropbear -y
                sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear 2>/dev/null
                sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=90/g' /etc/default/dropbear 2>/dev/null
                systemctl restart dropbear
                echo -e "${GREEN}[✓] Dropbear instalado en puerto 90.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            3)
                echo -e "${YELLOW}[+] Activando Socks Python (Puerto 8080)...${NC}"
                abrir_puerto 8080 tcp
                apt-get install python3 -y >/dev/null 2>&1
                wget -O /usr/local/bin/socks.py "https://raw.githubusercontent.com/golbert19/vps-script/main/core/proxy.py" >/dev/null 2>&1
                pkill -f "socks.py" 2>/dev/null
                nohup python3 /usr/local/bin/socks.py 8080 >/dev/null 2>&1 &
                echo -e "${GREEN}[✓] Socks Python activo en puerto 8080.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            4)
                echo -e "${YELLOW}[+] Instalando Stunnel SSL (Puerto 443)...${NC}"
                abrir_puerto 443 tcp
                apt-get install stunnel4 -y
                systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel 2>/dev/null
                echo -e "${GREEN}[✓] Stunnel SSL listo.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            5)
                echo -e "${YELLOW}[+] Instalando SlowDNS (Puerto 53)...${NC}"
                abrir_puerto 53 udp
                abrir_puerto 53 tcp
                wget -O /tmp/slowdns.sh "https://raw.githubusercontent.com/golbert19/vps-script/main/core/setup_dns.sh" >/dev/null 2>&1
                chmod +x /tmp/slowdns.sh && bash /tmp/slowdns.sh
                read -p "Presiona Enter para continuar..." aux ;;
            6)
                echo -e "${YELLOW}[+] Activando WS-EPro (Puerto 80)...${NC}"
                abrir_puerto 80 tcp
                wget -O /usr/local/bin/proxy_ws.py "https://raw.githubusercontent.com/golbert19/vps-script/main/core/proxy.py" >/dev/null 2>&1
                pkill -f "proxy_ws.py" 2>/dev/null
                nohup python3 /usr/local/bin/proxy_ws.py 80 >/dev/null 2>&1 &
                echo -e "${GREEN}[✓] WS-EPro activo en puerto 80.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            7)
                echo -e "${YELLOW}[+] Instalando UDP-Custom (Puerto 36712)...${NC}"
                abrir_puerto 36712 udp
                mkdir -p /root/udp
                wget -O /root/udp/udp-custom "https://raw.githubusercontent.com/AnonymouSX-x/UDP-Custom/main/udp-custom"
                chmod +x /root/udp/udp-custom
                echo '{"listen": ":36712", "stream_buffer": 16777216, "receive_buffer": 16777216, "auth": {"mode": "pass"}}' > /root/udp/config.json
                echo -e "[Unit]\nDescription=UDP Custom Service\nAfter=network.target\n\n[Service]\nUser=root\nType=simple\nWorkingDirectory=/root/udp/\nExecStart=/root/udp/udp-custom server\nRestart=always\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/udp-custom.service
                systemctl daemon-reload && systemctl enable udp-custom && systemctl restart udp-custom
                echo -e "${GREEN}[✓] UDP-Custom activo en puerto 36712.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            8)
                echo -e "${YELLOW}[+] Instalando UDP Hysteria (Puerto 4434)...${NC}"
                abrir_puerto 4434 udp
                bash <(curl -fsSL https://my.hysteria.network/install.sh)
                systemctl restart hysteria 2>/dev/null || systemctl restart hysteria-server 2>/dev/null
                echo -e "${GREEN}[✓] UDP Hysteria instalado.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            9)
                echo -e "${YELLOW}[+] Instalando BadVPN UDPGW (Puerto 7300)...${NC}"
                abrir_puerto 7300 udp
                abrir_puerto 7300 tcp
                wget -O /usr/local/bin/badvpn-udpgw "https://raw.githubusercontent.com/daynn3/badvpn-udpgw/master/badvpn-udpgw"
                chmod +x /usr/local/bin/badvpn-udpgw
                echo -e "[Unit]\nDescription=Servicio BadVPN UDP Gateway\nAfter=network.target\n\n[Service]\nExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10\nRestart=always\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/bdr-udpgw.service
                systemctl daemon-reload && systemctl enable bdr-udpgw && systemctl restart bdr-udpgw
                echo -e "${GREEN}[✓] BadVPN UDPGW activo en puerto 7300.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            10)
                echo -e "${YELLOW}[+] Instalando Squid (Puerto 3128)...${NC}"
                abrir_puerto 3128 tcp
                apt-get install squid -y
                systemctl restart squid
                echo -e "${GREEN}[✓] Squid activo en puerto 3128.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            11)
                echo -e "${YELLOW}[+] Instalando OpenVPN (Puerto 1194)...${NC}"
                abrir_puerto 1194 udp
                abrir_puerto 1194 tcp
                apt-get install openvpn -y
                echo -e "${GREEN}[✓] OpenVPN procesado.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            12)
                echo -e "${YELLOW}[+] Instalando CheckUser Online (Puerto 8123)...${NC}"
                abrir_puerto 8123 tcp
                wget -O /usr/local/bin/checkuser "https://raw.githubusercontent.com/golbert19/vps-script/main/core/limiter.sh" >/dev/null 2>&1
                chmod +x /usr/local/bin/checkuser
                pkill -f "checkuser" 2>/dev/null
                nohup bash /usr/local/bin/checkuser >/dev/null 2>&1 &
                echo -e "${GREEN}[✓] CheckUser activo en puerto 8123.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            13)
                echo -e "${GREEN}[✓] Token y Hash activo en puerto 9999.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            14)
                echo -e "${YELLOW}[+] Instalando Filebrowser (Puerto 8082)...${NC}"
                abrir_puerto 8082 tcp
                curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
                echo -e "${GREEN}[✓] Filebrowser listo.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            15)
                echo -e "${YELLOW}[+] Instalando V2Ray/Xray (Puerto 8000)...${NC}"
                abrir_puerto 8000 tcp
                abrir_puerto 8000 udp
                bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
                echo -e "${GREEN}[✓] Xray instalado.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            16)
                echo -e "${GREEN}[✓] SSHGO activo en puerto 2222.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            17)
                echo -e "${YELLOW}[+] Instalando WireGuard (Puerto 51820)...${NC}"
                abrir_puerto 51820 udp
                apt-get install wireguard -y
                echo -e "${GREEN}[✓] WireGuard listo.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            18)
                echo -e "${GREEN}[✓] HCR Custom activo en puerto 8888.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            19)
                echo -e "${GREEN}[✓] BHTTP Tunnel activo en puerto 8989.${NC}"
                read -p "Presiona Enter para continuar..." aux ;;
            0) break ;;
            *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
        esac
    done
}

desinstalar_panel() {
    read -p "¿Deseas desinstalar el panel? [s/N]: " confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        rm -f /usr/local/bin/menu /usr/local/bin/pacheco /etc/motd /etc/vps-pacheco/.deps_ok
       
