
#!/bin/bash
# ======================================================
# PANEL ADMPACHECO - GESTOR VPS
# ======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verificar root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Debes ejecutar como root.${NC}"
    exit 1
fi

# Configuración
REPO_URL="https://raw.githubusercontent.com/pachecoccv-png/admpacheco/main"
SCRIPT_DIR="/opt/admpacheco"
mkdir -p $SCRIPT_DIR

# Descargar archivos del repositorio
descargar_archivos() {
    echo -e "${YELLOW}[+] Descargando archivos...${NC}"
    archivos=("dropbear.sh" "stunnel.sh" "squid.sh" "udp_custom.sh" "badvpn.sh" "websocket.sh" "usuarios.sh")
    
    for archivo in "${archivos[@]}"; do
        wget -q -O "$SCRIPT_DIR/$archivo" "$REPO_URL/$archivo" 2>/dev/null
        chmod +x "$SCRIPT_DIR/$archivo"
    done
    
    echo -e "${GREEN}[✓] Archivos listos${NC}"
    sleep 1
}

# Abrir puerto
abrir_puerto() {
    local port=$1
    local proto=${2:-tcp}
    ufw allow $port/$proto >/dev/null 2>&1 || true
    iptables -I INPUT -p $proto --dport $port -j ACCEPT >/dev/null 2>&1 || true
}

# Verificar estado
check_status() {
    local port=$1
    local name=$2
    if ss -tuln 2>/dev/null | grep -q ":$port " || pgrep -f "$name" >/dev/null; then
        echo -e "${GREEN}[ON]${NC}"
    else
        echo -e "${RED}[OFF]${NC}"
    fi
}

# Contar usuarios
contar_usuarios() {
    activos=$(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd | wc -l)
    echo "$activos"
}

# Menú Protocolos
menu_protocolos() {
    while true; do
        clear
        echo -e "${YELLOW}------------------------------------------------${NC}"
        echo -e "${YELLOW}      ADMINISTRADOR DE PROTOCOLOS               ${NC}"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        echo -e " [1]> Dropbear (90)        $(check_status 90 dropbear)"
        echo -e " [2]> Stunnel SSL (443)     $(check_status 443 stunnel)"
        echo -e " [3]> Squid Proxy (3128)    $(check_status 3128 squid)"
        echo -e " [4]> WS-EPro (80)          $(check_status 80 python3)"
        echo -e " [5]> UDP-Custom (36712)    $(check_status 36712 udp-custom)"
        echo -e " [6]> BadVPN UDPGW (7300)   $(check_status 7300 badvpn)"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        echo -e " [0]> VOLVER"
        echo -e "${YELLOW}------------------------------------------------${NC}"
        read -r -p " Ingresa una Opcion: " op_prot

        case $op_prot in
            1) bash "$SCRIPT_DIR/dropbear.sh"; read -r -p "Enter para continuar..." aux ;;
            2) bash "$SCRIPT_DIR/stunnel.sh"; read -r -p "Enter para continuar..." aux ;;
            3) bash "$SCRIPT_DIR/squid.sh"; read -r -p "Enter para continuar..." aux ;;
            4) bash "$SCRIPT_DIR/websocket.sh"; read -r -p "Enter para continuar..." aux ;;
            5) bash "$SCRIPT_DIR/udp_custom.sh"; read -r -p "Enter para continuar..." aux ;;
            6) bash "$SCRIPT_DIR/badvpn.sh"; read -r -p "Enter para continuar..." aux ;;
            0) break ;;
            *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# Menú Principal
menu_principal() {
    while true; do
        clear
        total_users=$(contar_usuarios)
        IP=$(wget -qO- ipv4.icanhazip.com || echo "127.0.0.1")
        
        echo -e "${RED}------------------------------------------------${NC}"
        echo -e "${YELLOW}         PANEL ADMPACHECO                      ${NC}"
        echo -e "${RED}================================================${NC}"
        echo -e " ${CYAN}IP:${NC}     $IP"
        echo -e " ${CYAN}FECHA:${NC}  $(date +'%d-%m-%Y')   ${CYAN}HORA:${NC} $(date +'%H:%M:%S')"
        echo -e "${RED}================================================${NC}"
        echo -e " ${CYAN}[1]> GESTIONAR USUARIOS ($total_users)${NC}"
        echo -e " ${CYAN}[2]> CONFIGURAR PROTOCOLOS${NC}"
        echo -e " ${CYAN}[3]> HERRAMIENTAS EXTRAS${NC}"
        echo -e "${RED}------------------------------------------------${NC}"
        echo -e " ${CYAN}[8]> SALIR DEL SCRIPT${NC}   ${CYAN}[9]> REINICIAR VPS${NC}"
        echo -e "${RED}------------------------------------------------${NC}"
        read -r -p " Ingresa una Opcion: " opcion

        case $opcion in
            1) bash "$SCRIPT_DIR/usuarios.sh"; read -r -p "Enter para continuar..." aux ;;
            2) menu_protocolos ;;
            3) clear
               echo -e "${YELLOW}--- HERRAMIENTAS ---${NC}"
               echo -e " [1] Actualizar sistema"
               echo -e " [2] Ver uso de disco"
               echo -e " [3] Ver uso de memoria"
               echo -e " [0] Volver"
               read -r -p "Opción: " h
               case $h in
                   1) apt update && apt upgrade -y ;;
                   2) df -h ;;
                   3) free -h ;;
               esac
               read -r -p "Enter para continuar..." aux ;;
            8) exit 0 ;;
            9) reboot ;;
        esac
    done
}

# ============= INICIO =============
descargar_archivos

# Crear comando 'menu'
cp "$0" /usr/local/bin/menu 2>/dev/null
chmod +x /usr/local/bin/menu

menu_principal
