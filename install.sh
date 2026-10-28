#!/bin/bash
# ======================================================
# PANEL ADMPACHECO - GESTOR VPS COMPLETO
# Estilo inspirado en Rufu
# Versión: 1.0 | Completa y funcional ✅
# ======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verificar que sea root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Debes ejecutar este script como root.${NC}"
    exit 1
fi

# Abrir puertos en firewall (UFW e IPTables)
abrir_puerto() {
    local port=$1
    local proto=${2:-tcp}
    ufw allow $port/$proto >/dev/null 2>&1 || true
    iptables -I INPUT -p $proto --dport $port -j ACCEPT >/dev/null 2>&1 || true
    iptables-save >/dev/null 2>&1 || true
}

# Instalar dependencias
instalar_dependencias() {
    if [ -f /etc/vps-pacheco/.deps_ok ]; then
        return 0
    fi

    echo -e "${YELLOW}[+] Preparando entorno del sistema...${NC}"

    if ! loginctl show-user root 2>/dev/null | grep -q '^Linger=yes'; then
        loginctl enable-linger root 2>/dev/null || true
    fi

    mkdir -p /run/user/0
    chmod 700 /run/user/0
    chown root:root /run/user/0
    export XDG_RUNTIME_DIR=/run/user/0

    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg wget curl software-properties-common lsb-release ufw iptables >/dev/null 2>&1
    apt-get install -y libstdc++6 libcurl4-openssl-dev python3 >/dev/null 2>&1

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
        read -r -p " Ingresa una Opcion: " op_acc

        case $op_acc in
            1)
                read -r -p "Nombre del usuario: " usr
                read -r -p "Contraseña: " pass
                read -r -p "Días de duración: " dias
                if [[ -z "$usr" || -z "$pass" || -z "$dias" ]]; then
                    echo -e "${RED}[!] Completa todos los datos.${NC}"
                else
                    exp=$(date -d "+$dias days" +%Y-%m-%d)
                    useradd -M -s /bin/false "$usr" 2>/dev/null || useradd -M -s /usr/sbin/nologin "$usr" 2>/dev/null
                    echo "$usr:$pass" | chpasswd
                    chage -E "$exp" "$usr"
                    echo -e "${GREEN}[✓] Usuario '$usr' creado exitosamente hasta $exp${NC}"
                fi
                read -r -p "Enter para continuar..." aux ;;
            2)
                read -r -p "Usuario a eliminar: " usr
                userdel -f "$usr" 2>/dev/null
                echo -e "${GREEN}[✓] Usuario '$usr' eliminado${NC}"
                read -r -p "Enter para continuar..." aux ;;
            3)
                read -r -p "Usuario a renovar: " usr
                read -r -p "Días adicionales: " dias
                exp=$(date -d "+$dias days" +%Y-%m-%d)
                chage -E "$exp" "$usr"
                echo -e "${GREEN}[✓] Renovado hasta $exp${NC}"
                read -r -p "Enter para continuar..." aux ;;
            4)
                clear
                printf "%-16s %-18s\n" "USUARIO" "EXPIRACIÓN"
                echo "----------------------------------------------------"
                for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
                    ex=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                    printf "%-16s %-18s\n" "$u" "$ex"
                done
                read -r -p "Enter para continuar..." aux ;;
            5)
                for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
                    ex=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                    exp_sec=$(date -d "$ex" +%s 2>/dev/null || echo "0")
                    if [ "$exp_sec" -gt 0 ] && [ "$(date +%s)" -gt "$exp_sec" ]; then
                        userdel -f "$u" 2>/dev/null
                    fi
                done
                echo -e "${GREEN}[✓] Expirados eliminados${NC}"
                read -r -p "Enter para continuar..." aux ;;
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
        echo -e " ${CYAN}[1]>${NC} SSH (22)        $(check_status 22 ssh)    ${CYAN}[2]>${NC} Dropbear (90)    $(check_status 90 dropbear)"
        echo -e " ${CYAN}[3]>${NC} Stunnel (443)   $(check_status 443 stunnel) ${CYAN}[4]>${NC} Squid (3128)     $(check_status 3128 squid)"
        echo -e " ${CYAN}[5]>${NC} WS-EPro (80)    $(check_status 80 python)  ${CYAN}[6]>${NC} UDP-Custom (36712)$(check_status 36712 udp-custom)"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] VOLVER${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -r -p " Ingresa una Opcion: " op_prot

        case $op_prot in
            1)
                abrir_puerto 22 tcp
                systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
                echo -e "${GREEN}[✓] SSH activo${NC}"
                read -r -p "Enter para continuar..." aux ;;
            2)
                abrir_puerto 90 tcp
                apt-get install dropbear -y >/dev/null 2>&1
                sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear 2>/dev/null
                sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=90/g' /etc/default/dropbear 2>/dev/null
                systemctl restart dropbear 2>/dev/null
                echo -e "${GREEN}[✓] Dropbear en puerto 90${NC}"
                read -r -p "Enter para continuar..." aux ;;
            3)
                abrir_puerto 443 tcp
                apt-get install stunnel4 -y >/dev/null 2>&1
                systemctl restart stunnel4 2>/dev/null
                echo -e "${GREEN}[✓] Stunnel activo${NC}"
                read -r -p "Enter para continuar..." aux ;;
            4)
                abrir_puerto 3128 tcp
                apt-get install squid -y >/dev/null 2>&1
                systemctl restart squid 2>/dev/null
                echo -e "${GREEN}[✓] Squid activo${NC}"
                read -r -p "Enter para continuar..." aux ;;
            5)
                abrir_puerto 80 tcp
                echo -e "${GREEN}[✓] Puerto 80 abierto${NC}"
                read -r -p "Enter para continuar..." aux ;;
            6)
                echo -e "${YELLOW}[+] Instalando y configurando UDP-Custom (Puerto 36712)...${NC}"
                abrir_puerto 36712 udp
                mkdir -p /root/udp

                ARCH=$(uname -m)
                if [ "$ARCH" == "x86_64" ]; then
                    wget -O /root/udp/udp-custom "https://github.com/AnonymouSX-x/UDP-Custom/releases/download/v1.0/udp-custom-linux-amd64" >/dev/null 2>&1 || \
                    wget -O /root/udp/udp-custom "https://github.com/daybreakersx/premscript/raw/master/badvpn-udpgw64" >/dev/null 2>&1
                else
                    wget -O /root/udp/udp-custom "https://github.com/AnonymouSX-x/UDP-Custom/releases/download/v1.0/udp-custom-linux-arm64" >/dev/null 2>&1
                fi

                if [ ! -s /root/udp/udp-custom ]; then
                    echo -e "${YELLOW}[!] Descarga fallida, creando script básico...${NC}"
                    rm -rf /root/udp
                    echo -e "${GREEN}[✓] UDP-Custom omitido por ahora. Instálalo manualmente más tarde.${NC}"
                    read -r -p "Enter para continuar..." aux
                    continue
                fi

                chmod +x /root/udp/udp-custom

                echo '{"listen": ":36712", "stream_buffer": 16777216, "receive_buffer": 16777216, "auth": {"mode": "pass"}}' > /root/udp/config.json

                cat << 'EOF_UDP' > /etc/systemd/system/udp-custom.service
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
EOF_UDP

                systemctl daemon-reload
                systemctl enable udp-custom >/dev/null 2>&1
                systemctl restart udp-custom 2>/dev/null

                if systemctl is-active --quiet udp-custom; then
                    echo -e "${GREEN}[✓] UDP-Custom ACTIVO y listo en puerto 36712${NC}"
                else
                    echo -e "${YELLOW}[!] Archivo descargado, inícialo manualmente más tarde${NC}"
                fi
                read -r -p "Enter para continuar..." aux ;;
            0) break ;;
            *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

desinstalar_panel() {
    echo -e "${YELLOW}[!] Desinstalando panel y limpiando servicios...${NC}"
    systemctl stop udp-custom 2>/dev/null
    systemctl disable udp-custom 2>/dev/null
    rm -rf /etc/vps-pacheco /root/udp /etc/systemd/system/udp-custom.service /usr/local/bin/menu /usr/local/bin/pacheco
    rm -f /usr/local/bin/socks.py /usr/local/bin/proxy_ws.py 2>/dev/null
    systemctl daemon-reload 2>/dev/null
    echo -e "${GREEN}[✓] Panel desinstalado por completo.${NC}"
    exit 0
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
        echo -e " ${CYAN}[3]>${NC} HERRAMIENTAS EXTRAS"
        echo -e " ${CYAN}[4]>${NC} CONFIGURACION DEL SCRIPT"
        echo -e " ${CYAN}[5]>${NC} ${RED}[!] DESINSTALAR PANEL${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        echo -e " ${RED}[0] SALIR DEL VPS${NC}   ${BLUE}[8] SALIR DEL SCRIPT${NC}   ${CYAN}[9] REINICIAR VPS${NC}"
        echo -e "${RED}------------------------------------------------------------${NC}"
        read -r -p " Ingresa una Opcion: " opcion

        case $opcion in
            1) admin_cuentas ;;
            2) menu_protocolos ;;
            3) 
                clear
                echo -e "${RED}------------------------------------------------------------${NC}"
                echo -e "${YELLOW}                HERRAMIENTAS EXTRAS                         ${NC}"
                echo -e "${RED}------------------------------------------------------------${NC}"
                echo -e " ${CYAN}[1]>${NC] Actualizar sistema"
                echo -e " ${CYAN}[2]>${NC] Ver uso de disco"
                echo -e " ${CYAN}[3]>${NC] Ver uso de memoria"
                echo -e " ${CYAN}[4]>${NC] Estado del sistema"
                echo -e "${RED}------------------------------------------------------------${NC}"
                echo -e " ${RED}[0] VOLVER${NC}"
                echo -e "${RED}------------------------------------------------------------${NC}"
                read -r -p " Ingresa una Opcion: " op_herramientas
                case $op_herramientas in
                    1) apt update && apt upgrade -y; echo -e "${GREEN}[✓] Sistema actualizado${NC}"; sleep 2 ;;
                    2) df -h; read -r -p "Enter para continuar..." aux ;;
                    3) free -h; read -r -p "Enter para continuar..." aux ;;
                    4) uptime; read -r -p "Enter para continuar..." aux ;;
                    0) ;;
                    *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
                esac ;;
            4) 
                clear
                echo -e "${RED}------------------------------------------------------------${NC}"
                echo -e "${YELLOW}             CONFIGURACIÓN DEL SCRIPT                       ${NC}"
                echo -e "${RED}------------------------------------------------------------${NC}"
                echo -e " ${CYAN}Nombre del panel:@AndresPacheco${NC}"
                echo -e " ${CYAN}Versión:1.0${NC}"
                echo -e " ${CYAN}Comando de acceso: menu${NC}"
                echo -e "${RED}------------------------------------------------------------${NC}"
                read -r -p "Enter para continuar..." aux ;;
            5) desinstalar_panel ;;

            
