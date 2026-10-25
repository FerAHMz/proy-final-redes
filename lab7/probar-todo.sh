#!/bin/bash
# Lab 7 – prueba de punta a punta de todas las actividades, sin interacción.
#
# Se corre desde la laptop (Git Bash en Windows, Linux o macOS) con los hosts
# bastion / it-01 / it-02 de lab7/ssh_config.example ya en ~/.ssh/config y
# ncat instalado en la laptop y en las instancias de TI.
#
# Abre cada túnel en segundo plano, lo prueba y lo cierra. Al final revisa que
# no haya quedado nada escuchando.
#
# Uso:
#   ./lab7/probar-todo.sh
set -uo pipefail

IT01=192.168.10.138
IT02=192.168.10.139
VENTAS=192.168.10.10
PUERTO=4444
OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)
PETICION='GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n'

ok=0; fallas=0; PIDS=()
TMP="$(mktemp -d)"

pasa()  { echo "  OK    $1"; ok=$((ok + 1)); }
falla() { echo "  FALLA $1"; fallas=$((fallas + 1)); }
probar() {  # probar "descripción" comando...
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then pasa "$desc"; else falla "$desc"; fi
}
seccion() { echo; echo "== $1"; }

# En Git Bash, kill no siempre cierra un .exe nativo (python, ncat): se usa taskkill
matar() {
  local pid=$1
  kill "$pid" 2>/dev/null
  if [ -r "/proc/$pid/winpid" ]; then
    taskkill //F //PID "$(cat "/proc/$pid/winpid")" >/dev/null 2>&1
  fi
  wait "$pid" 2>/dev/null
}
limpiar() {
  for pid in "${PIDS[@]}"; do matar "$pid"; done
  PIDS=()
}
trap 'limpiar; rm -rf "$TMP"' EXIT

# Espera hasta 15 s a que algo escuche en 127.0.0.1:$1. Se corta antes si el
# proceso que debía abrirlo ($2, el último en segundo plano) ya murió.
esperar_puerto() {
  local fin=$((SECONDS + 15)) pid=${2:-${PIDS[-1]:-}}
  while [ $SECONDS -lt $fin ]; do
    [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && return 1
    (echo >"/dev/tcp/127.0.0.1/$1") 2>/dev/null && return 0
    sleep 0.5
  done
  return 1
}
puerto_libre() { ! (echo >"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

en() { local h=$1; shift; ssh "${OPTS[@]}" "$h" "$@"; }

# ---------------------------------------------------------------------------
seccion "Requisitos en la laptop"
for cmd in ssh curl ncat; do
  probar "$cmd instalado" command -v "$cmd"
done
# En Windows, python3 puede ser el acceso directo de la Microsoft Store que no hace nada
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null && "$c" -c 'print(1)' >/dev/null 2>&1; then PY=$c; break; fi
done
if [ -n "$PY" ]; then pasa "python instalado"; else falla "python instalado"; fi
for h in bastion it-01 it-02; do
  # ssh -G siempre muestra un hostname; si el host está configurado, no es el alias
  probar "host $h en ~/.ssh/config" bash -c "[ \"\$(ssh -G $h | awk '\$1==\"hostname\"{print \$2}')\" != $h ]"
done
LLAVE=$(ssh -G bastion 2>/dev/null | awk '$1=="identityfile"{print $2; exit}')
LLAVE="${LLAVE/#\~/$HOME}"
if [ -f "$LLAVE" ]; then pasa "llave encontrada ($LLAVE)"; else falla "llave encontrada ($LLAVE)"; fi

# ---------------------------------------------------------------------------
seccion "3.1 Conexión por llaves"
# BatchMode=yes no deja pedir contraseña: si conecta, fue con la llave
probar "SSH al Bastion"   en bastion true
probar "SSH a it-01"      bash -c "ssh ${OPTS[*]} it-01 'hostname -I' | grep -q $IT01"
probar "SSH a it-02"      bash -c "ssh ${OPTS[*]} it-02 'hostname -I' | grep -q $IT02"
probar "autenticación por llave pública" bash -c "ssh -v ${OPTS[*]} it-02 true 2>&1 | grep -q 'using \"publickey\"'"
probar "ncat instalado en it-01" en it-01 'command -v ncat'
probar "ncat instalado en it-02" en it-02 'command -v ncat'

# ---------------------------------------------------------------------------
seccion "3.2 Túnel local (-L 8080)"
ssh "${OPTS[@]}" -N -o ExitOnForwardFailure=yes -L 8080:rrhh.barrilete.dev:80 bastion &
PIDS+=($!)
if esperar_puerto 8080; then
  probar "intranet por nombre (Barrilete People)" bash -c "curl -s --max-time 10 -H 'Host: rrhh.barrilete.dev' http://127.0.0.1:8080/ | grep -q 'Barrilete People'"
  # curl sale con 52 (Empty reply) cuando Nginx hace return 444
  curl -s --max-time 10 http://127.0.0.1:8080/ >/dev/null 2>&1
  if [ $? -eq 52 ]; then pasa "por localhost Nginx corta la conexión (444)"; else falla "por localhost Nginx corta la conexión (444)"; fi
else
  falla "el túnel -L no levantó el 8080"
fi
limpiar

# ---------------------------------------------------------------------------
seccion "3.2 Túnel reverse (-R 9090)"
if [ -n "$PY" ]; then
  MARCA="lab7-reverse-$RANDOM"
  echo "$MARCA" > "$TMP/index.html"
  "$PY" -m http.server 8000 --bind 127.0.0.1 --directory "$TMP" >/dev/null 2>&1 &
  PIDS+=($!)
  esperar_puerto 8000 || falla "servidor local en el 8000"
  ssh "${OPTS[@]}" -N -o ExitOnForwardFailure=yes -R 9090:localhost:8000 bastion &
  PIDS+=($!)
  sleep 3
  probar "el Bastion llega a la laptop por localhost:9090" bash -c "ssh ${OPTS[*]} bastion 'curl -s --max-time 10 localhost:9090' | grep -q $MARCA"
  probar "el 9090 escucha solo en loopback del Bastion" bash -c "! ssh ${OPTS[*]} bastion 'ss -tln' | grep ':9090 ' | grep -vE '127.0.0.1:9090|\[::1\]:9090' | grep -q ."
  limpiar
else
  falla "túnel reverse (falta python)"
fi

# ---------------------------------------------------------------------------
seccion "3.2 Modo dynamic (-D 1080)"
ssh "${OPTS[@]}" -N -o ExitOnForwardFailure=yes -D 1080 bastion &
PIDS+=($!)
if esperar_puerto 1080; then
  probar "socks5h: la intranet se resuelve en el Bastion" bash -c "curl -s --max-time 15 --socks5-hostname 127.0.0.1:1080 http://rrhh.barrilete.dev | grep -q 'Barrilete People'"
  probar "socks5 (sin h): la laptop no resuelve el nombre" bash -c "! curl -s --max-time 15 --socks5 127.0.0.1:1080 http://rrhh.barrilete.dev"
  probar "salida a Internet por el proxy" bash -c "curl -s --max-time 15 --socks5-hostname 127.0.0.1:1080 https://example.org/ | grep -q 'Example Domain'"
else
  falla "el túnel -D no levantó el 1080"
fi
limpiar

# ---------------------------------------------------------------------------
seccion "3.2 Multi-hop laptop → Bastion → it-01 → it-02"
probar "ssh -J bastion,it-01: it-02 ve la conexión desde it-01" bash -c "ssh ${OPTS[*]} -J bastion,it-01 it-02 'echo \$SSH_CONNECTION' | grep -q '^$IT01 '"

# ---------------------------------------------------------------------------
seccion "3.3 ncat"
# Chat local: un mensaje de una terminal a otra por el 4444 de la laptop
ncat -l 127.0.0.1 $PUERTO > "$TMP/chat-local.txt" 2>/dev/null &
PIDS+=($!)
if esperar_puerto $PUERTO; then
  echo "hola chat local" | ncat --send-only 127.0.0.1 $PUERTO >/dev/null 2>&1
  sleep 1
  probar "chat local por el 4444" grep -q "hola chat local" "$TMP/chat-local.txt"
else
  falla "chat local (ncat -l no levantó el 4444)"
fi
limpiar

# Chat entre TI: it-02 escucha (con timeout para no quedar colgado) e it-01 manda
ssh "${OPTS[@]}" it-02 "timeout 20 ncat -l $PUERTO > /tmp/lab7-chat.txt" &
PIDS+=($!)
sleep 3
en it-01 "echo 'hola desde it-01' | ncat --send-only $IT02 $PUERTO" >/dev/null 2>&1
wait "${PIDS[-1]}" 2>/dev/null; PIDS=()
probar "chat it-01 → it-02 por el 4444" bash -c "ssh ${OPTS[*]} it-02 'cat /tmp/lab7-chat.txt' | grep -q 'hola desde it-01'"
en it-02 'rm -f /tmp/lab7-chat.txt' >/dev/null 2>&1

# HTTP y HTTPS desde la laptop y desde it-01 (--no-shutdown: ver lab7/ncat/http.sh)
probar "HTTP a example.org desde la laptop" bash -c "printf '$PETICION' | ncat --no-shutdown example.org 80 | grep -q 'HTTP/1.1 200'"
probar "HTTPS a example.org desde la laptop" bash -c "printf '$PETICION' | ncat --no-shutdown --ssl example.org 443 | grep -q 'Example Domain'"
probar "HTTP a example.org desde it-01" bash -c "ssh ${OPTS[*]} it-01 \"printf '$PETICION' | ncat --no-shutdown example.org 80\" | grep -q 'HTTP/1.1 200'"
probar "HTTPS a example.org desde it-01" bash -c "ssh ${OPTS[*]} it-01 \"printf '$PETICION' | ncat --no-shutdown --ssl example.org 443\" | grep -q 'Example Domain'"

# Transferencia de un .txt con verificación sha256
en it-01 "seq 1 500 | sed 's/^/linea /' > /tmp/lab7-prueba.txt" >/dev/null 2>&1
ssh "${OPTS[@]}" it-02 "timeout 20 ncat -l $PUERTO > /tmp/lab7-recibido.txt" &
PIDS+=($!)
sleep 3
en it-01 "ncat --send-only $IT02 $PUERTO < /tmp/lab7-prueba.txt" >/dev/null 2>&1
wait "${PIDS[-1]}" 2>/dev/null; PIDS=()
h1=$(en it-01 'sha256sum /tmp/lab7-prueba.txt' 2>/dev/null | cut -d' ' -f1)
h2=$(en it-02 'sha256sum /tmp/lab7-recibido.txt' 2>/dev/null | cut -d' ' -f1)
if [ -n "$h1" ] && [ "$h1" = "$h2" ]; then pasa "transferencia it-01 → it-02 con sha256 igual"; else falla "transferencia it-01 → it-02 con sha256 igual"; fi
en it-01 'rm -f /tmp/lab7-prueba.txt' >/dev/null 2>&1
en it-02 'rm -f /tmp/lab7-recibido.txt' >/dev/null 2>&1

# ---------------------------------------------------------------------------
seccion "Hardening"
# Desde Ventas, el SG descarta el paquete: la conexión se queda esperando (timeout = 124)
for p in 22 $PUERTO; do
  ssh "${OPTS[@]}" -i "$LLAVE" -J bastion "ec2-user@$VENTAS" "timeout 5 bash -c '</dev/tcp/$IT02/$p'" >/dev/null 2>&1
  if [ $? -eq 124 ]; then pasa "Ventas no llega a it-02:$p"; else falla "Ventas no llega a it-02:$p"; fi
done
for p in 8080 9090 1080 2201 2202 $PUERTO 8000; do
  probar "laptop: nada escucha en el $p" puerto_libre "$p"
done
for h in bastion it-01 it-02; do
  probar "$h: nada escucha en 9090 ni 4444" bash -c "! ssh ${OPTS[*]} $h 'ss -tln' | grep -qE ':(9090|$PUERTO) '"
done

# ---------------------------------------------------------------------------
echo
echo "Resultado: $ok correctas, $fallas con falla"
[ "$fallas" -eq 0 ]
