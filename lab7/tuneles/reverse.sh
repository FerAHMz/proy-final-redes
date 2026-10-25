#!/bin/bash
# Lab 7 – 3.2 Túnel reverse (-R) desde la laptop hacia el Bastion.
#
# Levanta un servidor web en la laptop (puerto 8000, solo localhost) y publica
# ese puerto en el Bastion como localhost:9090. Así el Bastion le habla a la
# laptop aunque la laptop esté detrás de NAT y no tenga IP pública.
#
# El 9090 queda solo en 127.0.0.1 del Bastion: no tocamos GatewayPorts (por
# defecto "no") y el SG del Bastion solo deja entrar el 22.
#
# Uso:
#   ./lab7/tuneles/reverse.sh    # Ctrl+C cierra el túnel y el servidor
#
# Con el túnel arriba, en otra terminal:
#   ssh bastion 'curl -s localhost:9090'
#   ssh bastion 'ss -tln | grep 9090'    # solo 127.0.0.1 y [::1]
set -euo pipefail

PY=$(command -v python3 || command -v python)
DIR=$(mktemp -d)

cat > "$DIR/index.html" <<EOF
<h1>Hola desde la laptop de $(whoami)</h1>
<p>Esto lo sirve $(hostname) y llegó al Bastion por un túnel ssh -R.</p>
EOF

# Servidor local solo en loopback, para no exponerlo a la red de la casa o la U
"$PY" -m http.server 8000 --bind 127.0.0.1 --directory "$DIR" &
SERVIDOR=$!
trap 'kill $SERVIDOR 2>/dev/null; rm -rf "$DIR"' EXIT
sleep 1

echo "Túnel reverse: bastion:localhost:9090 -> laptop:localhost:8000"
echo "Probalo con: ssh bastion 'curl -s localhost:9090' (Ctrl+C para cerrar)"

ssh -N -o ExitOnForwardFailure=yes -R 9090:localhost:8000 bastion
