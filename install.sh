#!/bin/bash
# ======================================================
# PANEL ADMPACHECO - GESTOR VPS COMPLETO
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

IP=$(wget -qO- ipv4.icanhazip.com || curl -s ipv4.icanhazip.com || echo "127.0.0.1")
SO=$(cat /etc/issue.net 2>/dev/null || uname -s)

check_status() {
    local port=$1
    local name=$2
    if ss -tuln 2>/dev/null | grep -q ":$port " \vert{}\vert{} pgrep -f "$name" >/dev/null; then
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
    clear
    contar_usuarios
    echo -e "${RED}------------------------------------------------------------${NC}"
    echo -e "${YELLOW}                     @AndresPacheco                         ${NC}"
    echo -e "${RED}============================================================${NC}"
    echo -e " ${CYAN}S.O:${NC}    $SO${CYAN}Fecha:${NC}$(date +'%d-%m-%Y')"
    echo -e " ${CYAN}IP:${NC}     $IP${CYAN}Hora:${NC}$(date +'%H:%M:%S')"
    echo -e "${RED}============================================================${NC}"
    echo -e " ${GREEN}ACTIVA:${NC}$activos   ${RED}EXPIRADA:${NC} $expirados${YELLOW}BLOQUEADA:${NC} 0${CYAN}TOTAL:${NC}$total"
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
        3) echo -e "${YELLOW}[+] Herramientas Extras...${NC}"; sleep 1; menu_principal ;;
        4) echo -e "${YELLOW}[+] Configuración de Bots API...${NC}"; sleep 1; menu_principal ;;
        5) echo -e "${YELLOW}[+] Configuración del Script...${NC}"; sleep 1; menu_principal ;;
        6) echo -e "${YELLOW}[+] Idioma: Español.${NC}"; sleep 1; menu_principal ;;
        7) desinstalar_panel ;;
        8) exit 0 ;;
        9) reboot ;;
        0) logout ;;
        *) echo -e "${RED}Opción no válida.${NC}"; sleep 1; menu_principal ;;
    esac
}

admin_cuentas() {
    clear
    echo -e "${RED}------------------------------------------------------------${NC}"
    echo -e "${YELLOW}             ADMINISTRAR CUENTAS (SSH/DROPBEAR)${NC}"
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
            read -p "Presiona Enter..." aux; admin_cuentas ;;
        2)
            read -p "Usuario a eliminar: " usr
            userdel -f "$usr" 2>/dev/null
            echo -e "${GREEN}[✓] Usuario '$usr' eliminado.${NC}"
            read -p "Presiona
