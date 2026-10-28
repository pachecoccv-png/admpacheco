
#!/bin/bash
# ======================================================
# PANEL ADMPACHECO - GESTOR VPS MODULAR PROFESIONAL
# ======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO="https://raw.githubusercontent.com/pachecoccv-png/admpacheco/main"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Debes ejecutar este script como root (sudo -i).${NC}"
    exit 1
fi

instalar_dependencias() {
    if [ -f /etc/vps-pacheco/.deps_ok ]; then
        return 0
    fi

    echo -e "${YELLOW}[+] Preparando entorno del sistema y dependencias esenciales...${NC}"

    if ! loginctl show-user root 2>/dev/null | grep -q '^Linger=yes'; then
        loginctl enable-linger root 2>/dev/null || true
    fi

    mkdir -p /run/user/0
    chmod 700 /run/user/0
    chown root:root /run/user/0
    export XDG_RUNTIME_DIR=/run/user/0

    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg wget curl software-properties-common lsb-release ufw iptables libstdc++6 libcurl4-openssl-dev python3 >/dev/null 2>&1

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

menu_protocolos() {
    while true; do
        clear
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e "${YELLOW}                ADMINISTRADOR DE PROTOCOLOS                 ${NC}"
        echo -e "${RED}============================================================${NC}"
        echo -e " ${CYAN}[1]>${NC} Dropbear (90)     $(check_status 90 dropbear)"
        echo -e " ${CYAN}[2]>${NC} Stunnel SSL (443) $(check_status 443 stunnel)"
        echo -e " ${CYAN}[3]>${NC} Squid Proxy (3128)$(check_status 3128 squid)"
        echo -e " ${CYAN}[4]>${NC} WS-EPro (80)      $(check_status 80 ws.py)"
        echo -e " ${CYAN}[5]>${NC} UDP-Custom (36712)$(check_status 36712 udp-custom)"
        echo -e " ${CYAN}[6]>${NC} BadVPN UDPGW(7300)$(check_status 7300 badvpn)"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] VOLVER${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -r -p " Ingresa una Opcion: " op_prot

        case $op_prot in
            1) bash <(curl -sSL "$REPO/dropbear.sh"); read -r -p "Enter para continuar..." aux ;;
            2) bash <(curl -sSL "$REPO/stunnel.sh"); read -r -p "Enter para continuar..." aux ;;
            3) bash <(curl -sSL "$REPO/squid.sh"); read -r -p "Enter para continuar..." aux ;;
            4) bash <(curl -sSL "$REPO/websocket.sh"); read -r -p "Enter para continuar..." aux ;;
            5) bash <(curl -sSL "$REPO/udp_custom.sh"); read -r -p "Enter para continuar..." aux ;;
            6) bash <(curl -sSL "$REPO/badvpn.sh"); read -r -p "Enter para continuar..." aux ;;
            0) break ;;
            *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
        esac
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
        echo -e " ${GREEN}ACTIVA:${NC} $activos   ${RED}EXPIRADA:${NC} $expirados   ${CYAN}TOTAL:${NC} $total"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${CYAN}[1]>${NC} ADMINISTRAR CUENTAS (SSH/DROPBEAR)"
        echo -e " ${CYAN}[2]>${NC} CONFIGURACION DE PROTOCOLOS"
        echo -e " ${CYAN}[3]>${NC} ${RED}[!] DESINSTALAR PANEL${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] SALIR DEL VPS${NC}   ${BLUE}[8] SALIR DEL SCRIPT${NC}   ${CYAN}[9] REINICIAR VPS${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -r -p " Ingresa una Opcion: " opcion

        case $opcion in
            1) bash <(curl -sSL "$REPO/usuarios.sh") ;;
            2) menu_protocolos ;;
            3)
                systemctl stop udp-custom bdr-udpgw dropbear stunnel4 ws-epro squid 2>/dev/null
                rm -rf /etc/vps-pacheco /root/udp /usr/local/bin/menu /usr/local/bin/pacheco /usr/local/bin/ws.py
                echo -e "${GREEN}[✓] Panel desinstalado por completo.${NC}"
                exit 0 ;;
            8) exit 0 ;;
            9) reboot ;;
            0) logout ;;
            *) echo -e "${RED}Opción no válida.${NC}"; sleep 1 ;;
        esac
    done
}

instalar_dependencias

cp "$0" /usr/local/bin/menu 2>/dev/null || true
chmod +x /usr/local/bin/menu
ln -sf /usr/local/bin/menu /usr/local/bin/pacheco 2>/dev/null || true
sed -i 's/\r$//' /usr/local/bin/menu 2>/dev/null || true

menu_principal
