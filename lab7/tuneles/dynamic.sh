#!/bin/bash
# Lab 7 – 3.2 Túnel dinámico (-D): la laptop como proxy SOCKS hacia la VPC.
#
# ssh abre un servidor SOCKS en 127.0.0.1:1080 de la laptop. Cada conexión que
# entra ahí dice a qué host y puerto quiere ir, y el Bastion abre esa conexión
# desde adentro de la VPC. A diferencia de -L, el destino no es fijo.
#
# Antes de correrlo:
#   1. Tener el host `bastion` en ~/.ssh/config (ver lab7/ssh_config.example)
#   2. Quitar del archivo hosts la línea `127.0.0.1 rrhh.barrilete.dev` si quedó
#      del túnel local: con SOCKS no hace falta y con socks5 (sin h) estorba
#
# Uso:
#   ./lab7/tuneles/dynamic.sh    # deja el proxy abierto; Ctrl+C lo cierra
#
# Con el proxy arriba, en otra terminal (en Windows PowerShell usá curl.exe):
#   curl --socks5-hostname localhost:1080 http://rrhh.barrilete.dev  → Barrilete People
#   curl --socks5          localhost:1080 http://rrhh.barrilete.dev  → Could not resolve host
#   curl --socks5-hostname localhost:1080 https://checkip.amazonaws.com → IP pública del Bastion
#
# Firefox: Ajustes → Configuración de red → Configuración manual del proxy
#   Servidor SOCKS: 127.0.0.1   Puerto: 1080   SOCKS v5
#   Marcar "Proxy DNS when using SOCKS v5" (la casilla justo debajo de SOCKS v5)
#   Dejar vacío el proxy HTTP y entrar a http://rrhh.barrilete.dev
set -euo pipefail

echo "Proxy SOCKS: 127.0.0.1:1080 -> bastion -> cualquier host:puerto de la VPC"
echo "Probalo con: curl --socks5-hostname localhost:1080 http://rrhh.barrilete.dev (Ctrl+C para cerrar)"

# -D 1080: servidor SOCKS4/SOCKS5 local. Sin bind_address escucha solo en loopback
#          (GatewayPorts del cliente queda en "no"), así nadie de la red local lo usa
# -N: no abre shell en el Bastion, solo el proxy
# ExitOnForwardFailure: si el 1080 ya está ocupado, falla en vez de quedarse sin proxy
ssh -N -o ExitOnForwardFailure=yes -D 1080 bastion
