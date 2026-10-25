#!/bin/bash
# Lab 7 – 3.3 Petición HTTPS a https://example.org/ con ncat.
#
# Es la misma petición que http.sh, pero con --ssl: ncat primero hace el
# handshake TLS con el servidor en el 443 y después manda el texto HTTP adentro
# del canal cifrado. Lo que viaja por la red ya no se puede leer; en la
# terminal sí vemos la respuesta porque ncat la descifra.
#
# Ojo: --ssl solo cifra, no revisa el certificado. Con --ssl-verify ncat
# además comprueba que el certificado sea válido para example.org (opción
# "verificar").
#
# --no-shutdown: por defecto, cuando printf termina, ncat cierra su lado de
# escritura (half-close) aunque la respuesta todavía no llegue. El servidor de
# example.org (Cloudflare) corta la conexión sin responder si el cliente cierra
# antes, así que la salida quedaba vacía. Con --no-shutdown ncat espera la
# respuesta y sale cuando el servidor cierra (por el Connection: close).
#
# Uso:
#   ./lab7/ncat/https.sh                # desde la laptop
#   ./lab7/ncat/https.sh it-01          # desde it-01 (el firewall deja el 443)
#   ./lab7/ncat/https.sh verificar      # igual, pero validando el certificado
#
# A mano, sin el script:
#   printf 'GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n' | ncat --no-shutdown --ssl example.org 443
set -euo pipefail

PETICION='GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n'

case "${1:-}" in
  "")
    echo "== GET https://example.org/ desde $(hostname)"
    printf "$PETICION" | ncat --no-shutdown --ssl example.org 443
    ;;
  verificar)
    echo "== GET https://example.org/ desde $(hostname), validando el certificado"
    # -v muestra la conexión SSL y la huella del certificado del servidor
    printf "$PETICION" | ncat -v --no-shutdown --ssl --ssl-verify example.org 443
    ;;
  *)
    echo "== GET https://example.org/ desde $1"
    ssh "$1" "printf '$PETICION' | ncat --no-shutdown --ssl example.org 443"
    ;;
esac
