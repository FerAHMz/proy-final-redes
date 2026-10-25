#!/bin/bash
# Lab 7 – 3.2 Túnel local (-L) hacia la intranet de RRHH.
#
# El puerto 8080 de la laptop se reenvía por SSH al Bastion, y el Bastion abre
# la conexión a rrhh.barrilete.dev:80. El nombre lo resuelve el Bastion con el
# DNS privado de Route 53, porque desde la laptop no existe.
#
# Antes de correrlo:
#   1. Tener el host `bastion` en ~/.ssh/config (ver lab7/ssh_config.example)
#   2. Agregar al archivo hosts de la laptop (con permisos de admin):
#        127.0.0.1 rrhh.barrilete.dev
#      Linux/macOS: /etc/hosts
#      Windows:     C:\Windows\System32\drivers\etc\hosts
#
# Uso:
#   ./lab7/tuneles/local.sh      # deja el túnel abierto; Ctrl+C lo cierra
#
# Con el túnel arriba, en otra terminal o en el navegador:
#   http://rrhh.barrilete.dev:8080    → Barrilete People
#   curl -v http://localhost:8080/    → Empty reply from server (444 de Nginx)
set -euo pipefail

echo "Túnel local: localhost:8080 -> bastion -> rrhh.barrilete.dev:80"
echo "Abrí http://rrhh.barrilete.dev:8080 (Ctrl+C para cerrar)"

# -N: no abre shell en el Bastion, solo el reenvío
# ExitOnForwardFailure: si el 8080 ya está ocupado, falla en vez de quedarse sin túnel
# Sin bind_address, ssh escucha solo en 127.0.0.1, así que nadie de la red local lo usa
ssh -N -o ExitOnForwardFailure=yes -L 8080:rrhh.barrilete.dev:80 bastion
