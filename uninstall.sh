
#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Requiere root'; exit 1; }
echo '===== ADMPACHECO | DESINSTALACION ====='
echo '[1] Solo panel y servicios propios (conservar SSH, Dropbear, Squid, Stunnel y usuarios)'
echo '[2] Panel y configuraciones propias de protocolos (no eliminar paquetes compartidos ni usuarios)'
echo '[0] Cancelar'
read -r -p 'Opcion: ' op || exit
[[ $op == 1 || $op == 2 ]] || exit 0
read -r -p 'Escribe DESINSTALAR para confirmar: ' ok
[[ $ok == DESINSTALAR ]] || exit 0
for s in admpacheco-wsepro admpacheco-udp; do systemctl disable --now "$s" 2>/dev/null || true; rm -f "/etc/systemd/system/$s.service"; done
if [[ $op == 2 ]]; then
 rm -f /etc/stunnel/admpacheco.conf
 if [[ -f /etc/admpacheco/backups/squid.conf ]]; then cp /etc/admpacheco/backups/squid.conf /etc/squid/squid.conf; systemctl restart squid || true; fi
 if [[ -f /etc/admpacheco/backups/dropbear.default ]]; then cp /etc/admpacheco/backups/dropbear.default /etc/default/dropbear; systemctl restart dropbear || true; fi
 systemctl restart stunnel4 2>/dev/null || true
fi
systemctl daemon-reload
rm -f /usr/local/bin/admpacheco
rm -rf /opt/admpacheco
echo 'Panel retirado. SSH y cuentas del sistema conservados.'
