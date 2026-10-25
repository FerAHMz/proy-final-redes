#!/bin/bash
# Lab 7 – 3.3 Chat con ncat entre dos equipos locales (o dos terminales).
#
# Un lado escucha en el 4444 y el otro se conecta. Lo que se escribe en una
# terminal aparece en la otra, en texto plano sobre TCP (sin cifrar).
#
# Antes de correrlo:
#   Linux:   sudo dnf install -y nmap-ncat   o   sudo apt install -y ncat
#   macOS:   brew install nmap
#   Windows: instalar Nmap (https://nmap.org/download) y usar Git Bash o PowerShell
#
# Uso:
#   ./lab7/ncat/chat-local.sh servidor          # equipo A (o terminal 1)
#   ./lab7/ncat/chat-local.sh cliente <ip>      # equipo B (o terminal 2)
#
#   Dos terminales en la misma laptop → <ip> = 127.0.0.1
#   Dos laptops en la misma red       → <ip> = IP del equipo A (ipconfig / ip -4 addr)
#
# Se cierra con Ctrl+C en cualquiera de los dos lados.
set -euo pipefail

PUERTO=4444

case "${1:-}" in
  servidor)
    echo "Escuchando chat en el puerto $PUERTO (Ctrl+C para cerrar)"
    # -l: modo escucha. Atiende a un solo cliente y termina cuando este se va
    ncat -l "$PUERTO"
    ;;
  cliente)
    ip="${2:?Falta la IP del servidor: $0 cliente <ip>}"
    echo "Conectando a $ip:$PUERTO (Ctrl+C para cerrar)"
    ncat "$ip" "$PUERTO"
    ;;
  *)
    echo "Uso: $0 {servidor|cliente <ip>}" >&2
    exit 1
    ;;
esac
