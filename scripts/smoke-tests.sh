#!/bin/bash
# Pruebas de la Fase 2 (matriz del spec). Se corre desde la laptop, después de
# `terraform apply`, con la llave cargada en el agente (ssh-add).
#
#   ./scripts/smoke-tests.sh            # muestra los resultados
#   ./scripts/smoke-tests.sh --guardar  # además los guarda en evidencias/
set -uo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
TF="$RAIZ/terraform"
B=$(terraform -chdir="$TF" output -raw bastion_public_ip)
FW_IP=$(terraform -chdir="$TF" output -raw fw_public_ip)
CLAVES=$(terraform -chdir="$TF" output -json ldap_user_passwords)

SALES=192.168.10.10 HR=192.168.10.196 IT=192.168.10.138 GUEST=192.168.10.74
WEB=192.168.10.164 LDAP=192.168.10.170 FW=192.168.10.181 BASTION=192.168.10.180

OPTS=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)
ok=0; fallas=0

# Ejecuta un comando en una instancia privada pasando por el Bastion.
# A Visitas solo se entra a través de TI (la NACL solo deja entrar a TI).
en() {
  local ip=$1; shift
  if [ "$ip" = "$GUEST" ]; then
    ssh "${OPTS[@]}" -J "ec2-user@$B,ec2-user@$IT" "ec2-user@$ip" "$@" 2>&1
  else
    ssh "${OPTS[@]}" -J "ec2-user@$B" "ec2-user@$ip" "$@" 2>&1
  fi
}

# Login por SSH de un usuario LDAP con su contraseña (sin interacción)
login() {
  local usuario=$1 ip=$2 askpass
  askpass=$(mktemp)
  printf '#!/bin/sh\necho "%s"\n' "$(echo "$CLAVES" | python3 -c "import sys,json;print(json.load(sys.stdin)['$usuario'])")" > "$askpass"
  chmod 700 "$askpass"
  SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
    ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
        -o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive,password \
        -o NumberOfPasswordPrompts=1 -J "ec2-user@$B" "$usuario@$ip" \
        'echo "ENTRÓ $(whoami)@$(hostname -s) grupos=$(id -Gn)"' 2>&1
  rm -f "$askpass"
}

# Para los casos negativos: el login no debe llegar a ejecutar nada
rechazado() {
  local r
  r=$(login "$1" "$2")
  if echo "$r" | grep -q "ENTRÓ"; then echo "ENTRÓ (no debía) $r"; else echo "RECHAZADO $r"; fi
}

# prueba <número> <descripción> <patrón esperado (grep -E)> <salida>
prueba() {
  local n=$1 desc=$2 patron=$3 salida=$4
  if echo "$salida" | grep -qE "$patron"; then
    printf "✅ %-3s %s\n" "$n" "$desc"; ok=$((ok + 1))
  else
    printf "❌ %-3s %s\n" "$n" "$desc"; fallas=$((fallas + 1))
  fi
  echo "$salida" | sed 's/^/       /' | head -6
}

# Espera (máx. 5 min) a que el DNS privado responda y SSSD esté conectado a LDAP;
# justo después de un apply la zona de Route 53 todavía se está propagando
esperar_servicios() {
  local i
  for i in $(seq 1 30); do
    ssh "${OPTS[@]}" "ec2-user@$B" 'getent hosts rrhh.barrilete.dev' >/dev/null 2>&1 &&
      en $SALES 'id vendedor1' | grep -q ventas-users &&
      en $HR 'id rrhh1' | grep -q rrhh-users && return 0
    sleep 10
  done
  echo "Aviso: DNS o LDAP todavía no responden; algunas pruebas pueden fallar"
}

correr() {
  echo "Pruebas Fase 2 – $(date '+%Y-%m-%d %H:%M %Z') – Bastion $B"
  echo

  echo "== Intranet (HTTP + DNS)"
  prueba 1 "Ventas abre http://rrhh.barrilete.dev" "Barrilete People" \
    "$(en $SALES 'curl -s -m 5 http://rrhh.barrilete.dev | grep -o "<title>.*</title>"')"
  prueba 2 "Por IP no responde (444)" "rc=52" \
    "$(en $SALES 'curl -s -m 5 http://192.168.10.164; echo "rc=$?"')"
  prueba 3 "DNS privado resuelve rrhh.barrilete.dev" "192\.168\.10\.164" \
    "$(en $SALES 'getent hosts rrhh.barrilete.dev')"
  prueba 4 "RRHH abre la intranet" "Barrilete People" \
    "$(en $HR 'curl -s -m 5 http://rrhh.barrilete.dev | grep -o "<title>.*</title>"')"
  prueba 5 "TI abre la intranet" "Barrilete People" \
    "$(en $IT 'curl -s -m 5 http://rrhh.barrilete.dev | grep -o "<title>.*</title>"')"
  prueba 6 "Visitas NO llega a la intranet" "rc=28" \
    "$(en $GUEST 'curl -s -m 5 http://rrhh.barrilete.dev; echo "rc=$?"')"

  echo; echo "== Visitas: Internet sí, red interna no"
  prueba 7 "Visitas sale a Internet con la IP del firewall ($FW_IP)" "$FW_IP" \
    "$(en $GUEST 'curl -s -m 10 https://checkip.amazonaws.com')"
  prueba 8 "Visitas no alcanza Ventas, TI ni Data Center" "^(100% ){3}$" \
    "$(en $GUEST 'for ip in 192.168.10.10 192.168.10.138 192.168.10.164; do ping -c 2 -W 2 $ip | grep -o "[0-9]*% packet loss" | cut -d" " -f1; done' | tr '\n' ' ')"
  prueba 9 "Intranet y LDAP sin IP pública" "^sin-ip-publica sin-ip-publica$" \
    "$(for r in 'aws_instance.datacenter[0]' 'aws_instance.ldap'; do terraform -chdir="$TF" state show "$r" | grep -qE '^ +public_ip += "[0-9]' && echo con-ip || echo sin-ip-publica; done | tr '\n' ' ' | sed 's/ $//')"

  echo; echo "== TI llega a todas; nadie llega a TI"
  prueba 10 "TI hace ping a Ventas, RRHH, Visitas, DC, LDAP, Bastion y firewall" "^(0% ){7}$" \
    "$(en $IT 'for ip in 192.168.10.10 192.168.10.196 192.168.10.74 192.168.10.164 192.168.10.170 192.168.10.180 192.168.10.181; do ping -c 2 -W 2 $ip | grep -o "[0-9]*% packet loss" | cut -d" " -f1; done' | tr '\n' ' ')"
  prueba 11 "Ventas NO llega a TI por SSH" "timed out" \
    "$(en $SALES 'ssh -n -T -o ConnectTimeout=5 -o BatchMode=yes 192.168.10.138')"
  prueba 12 "RRHH NO llega a TI por ping" "100% packet loss" \
    "$(en $HR 'ping -c 2 -W 2 192.168.10.138')"

  echo; echo "== LDAP"
  prueba 13 "Ventas resuelve usuarios desde LDAP" "ventas-users" \
    "$(en $SALES 'id vendedor1')"
  prueba 14 "vendedor1 entra a Ventas" "ENTRÓ vendedor1" "$(login vendedor1 $SALES)"
  prueba 15 "rrhh1 NO entra a Ventas" "^RECHAZADO" "$(rechazado rrhh1 $SALES)"
  prueba 16 "rrhh1 entra a RRHH" "ENTRÓ rrhh1" "$(login rrhh1 $HR)"
  prueba 17 "vendedor1 NO entra a RRHH" "^RECHAZADO" "$(rechazado vendedor1 $HR)"
  prueba 18 "El rechazo queda registrado en Ventas" "Access denied for user rrhh1" \
    "$(en $SALES 'sudo journalctl -u sshd --no-pager | grep "Access denied for user rrhh1" | tail -1')"
  prueba 19 "El directorio en el Data Center tiene los 3 grupos" "ventas-users.*|rrhh-users|ti-admins" \
    "$(en $LDAP 'ldapsearch -x -LLL "(objectClass=posixGroup)" cn | grep "^cn:"')"

  echo; echo "== Hardening y firewall"
  prueba 20a "Web solo escucha 22 y 80" "^22 80$" \
    "$(en $WEB 'sudo ss -Htln | awk "{print \$4}" | grep -v "127.0.0" | sed "s/.*://" | sort -un | tr "\n" " " | sed "s/ $//"')"
  prueba 20b "LDAP solo escucha 22 y 636" "^22 636$" \
    "$(en $LDAP 'sudo ss -Htln | awk "{print \$4}" | grep -v "127.0.0" | sed "s/.*://" | sort -un | tr "\n" " " | sed "s/ $//"')"
  prueba 21 "Firewall con NAT (masquerade) y política drop" "masquerade" \
    "$(en $FW 'sudo nft list ruleset | grep -E "policy drop|masquerade"')"

  echo
  echo "Resultado: $ok correctas, $fallas fallidas"
}

esperar_servicios

if [ "${1:-}" = "--guardar" ]; then
  mkdir -p "$RAIZ/evidencias"
  archivo="$RAIZ/evidencias/pruebas-$(date '+%Y-%m-%d_%H%M').txt"
  correr | tee "$archivo"
  echo "Guardado en ${archivo#$RAIZ/}"
else
  correr
fi
