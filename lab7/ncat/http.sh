#!/bin/bash
# Lab 7 – 3.3 Petición HTTP a http://example.org con ncat.
#
# ncat abre una conexión TCP al 80 y le mandamos la petición HTTP escrita a
# mano. Lo que responde el servidor (cabeceras + HTML) sale tal cual en la
# terminal. Así se ve que HTTP es solo texto viajando sobre TCP.
#
# Cada línea de la petición termina en \r\n (CRLF) y una línea vacía marca el
# fin de las cabeceras. Host es obligatorio en HTTP/1.1 y Connection: close
# hace que el servidor cierre al terminar, así ncat sale solo.
#
# --no-shutdown: por defecto, cuando printf termina, ncat cierra su lado de
# escritura (half-close) aunque la respuesta todavía no llegue. El servidor de
# example.org (Cloudflare) corta la conexión sin responder si el cliente cierra
# antes, así que la salida quedaba vacía. Con --no-shutdown ncat espera la
# respuesta y sale cuando el servidor cierra (por el Connection: close).
#
# Uso:
#   ./lab7/ncat/http.sh          # desde la laptop
#   ./lab7/ncat/http.sh it-01    # desde it-01 (sale por el firewall, que deja el 80)
#
# A mano, sin el script:
#   printf 'GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n' | ncat --no-shutdown example.org 80
set -euo pipefail

PETICION='GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n'

if [ -n "${1:-}" ]; then
  echo "== GET http://example.org/ desde $1"
  ssh "$1" "printf '$PETICION' | ncat --no-shutdown example.org 80"
else
  echo "== GET http://example.org/ desde $(hostname)"
  printf "$PETICION" | ncat --no-shutdown example.org 80
fi
