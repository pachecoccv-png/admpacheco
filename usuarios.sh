
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
                echo -e "${RED}[!] Todos los campos son obligatorios.${NC}"
            elif id "$usr" &>/dev/null; then
                echo -e "${RED}[!] El usuario '$usr' ya existe.${NC}"
            else
                exp=$(date -d "+$dias days" +%Y-%m-%d)
                useradd -M -s /bin/false "$usr" 2>/dev/null || useradd -M -s /usr/sbin/nologin "$usr" 2>/dev/null
                echo "$usr:$pass" | chpasswd
                chage -E "$exp" "$usr"
                echo -e "${GREEN}[✓] Usuario '$usr' creado exitosamente hasta $exp.${NC}"
            fi
            read -r -p "Presiona Enter para continuar..." aux ;;
        2)
            read -r -p "Usuario a eliminar: " usr
            if id "$usr" &>/dev/null; then
                userdel -f "$usr" 2>/dev/null
                echo -e "${GREEN}[✓] Usuario '$usr' eliminado.${NC}"
            else
                echo -e "${RED}[!] El usuario no existe.${NC}"
            fi
            read -r -p "Presiona Enter para continuar..." aux ;;
        3)
            read -r -p "Usuario a renovar: " usr
            read -r -p "Días adicionales: " dias
            if id "$usr" &>/dev/null; then
                exp=$(date -d "+$dias days" +%Y-%m-%d)
                chage -E "$exp" "$usr"
                echo -e "${GREEN}[✓] Usuario '$usr' renovado hasta $exp.${NC}"
            else
                echo -e "${RED}[!] El usuario no existe.${NC}"
            fi
            read -r -p "Presiona Enter para continuar..." aux ;;
        4)
            clear
            printf "%-16s %-18s\n" "USUARIO" "EXPIRACIÓN"
            echo "----------------------------------------------------"
            for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
                ex=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                printf "%-16s %-18s\n" "$u" "$ex"
            done
            read -r -p "Presiona Enter para continuar..." aux ;;
        5)
            now_sec=$(date +%s)
            for u in $(awk -F: '$3>=1000 && $3!=65534 {print $1}' /etc/passwd); do
                ex=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                exp_sec=$(date -d "$ex" +%s 2>/dev/null || echo "0")
                if [ "$exp_sec" -gt 0 ] && [ "$now_sec" -gt "$exp_sec" ]; then
                    userdel -f "$u" 2>/dev/null
                    echo -e "${YELLOW}[-] Usuario '$u' eliminado por expiración.${NC}"
                fi
            done
            echo -e "${GREEN}[✓] Limpieza completada.${NC}"
            read -r -p "Presiona Enter para continuar..." aux ;;
        0) break ;;
        *) sleep 1 ;;
    esac
done
