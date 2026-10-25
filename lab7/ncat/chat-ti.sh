#!/bin/bash
# Lab 7 – 3.3 Chat con ncat entre it-01 e it-02.
#
# it-02 escucha en el 4444 e it-01 se conecta. El SG it_self deja pasar el TCP
# 4444 solo entre instancias de TI, así que nadie más de la VPC llega a ese chat.
#
# Se maneja todo desde la laptop por SSH (ver lab7/ssh_config.example).
#
# Uso:
#   ./lab7/ncat/chat-ti.sh instalar    # una vez: nmap-ncat en it-01 e it-02
#   ./lab7/ncat/chat-ti.sh servidor    # terminal 1: it-02 escucha en el 4444
#   ./lab7/ncat/chat-ti.sh cliente     # terminal 2: it-01 se conecta a it-02
#   ./lab7/ncat/chat-ti.sh verificar   # después: que ya nadie escuche en el 4444
#
# A mano, sin el script:
#   it-02$ ncat -l 4444
#   it-01$ ncat 192.168.10.139 4444
set -euo pipefail

IT02=192.168.10.139
PUERTO=4444

case "${1:-}" in
  instalar)
    # dnf sale por HTTPS (443), que el firewall sí deja pasar desde las privadas
    for host in it-01 it-02; do
      echo "== $host"
      ssh "$host" 'sudo dnf install -y nmap-ncat && ncat --version'
    done
    ;;
  servidor)
    echo "it-02 escuchando en el $PUERTO (Ctrl+C para cerrar)"
    # -t: terminal interactiva, así Ctrl+C cierra ncat en it-02 y no queda colgado
    ssh -t it-02 "ncat -l $PUERTO"
    ;;
  cliente)
    echo "it-01 conectando a $IT02:$PUERTO (Ctrl+C para cerrar)"
    ssh -t it-01 "ncat $IT02 $PUERTO"
    ;;
  verificar)
    for host in it-01 it-02; do
      echo "== $host"
      ssh "$host" "ss -tln | grep ':$PUERTO ' || echo 'nadie escucha en el $PUERTO'"
    done
    ;;
  *)
    echo "Uso: $0 {instalar|servidor|cliente|verificar}" >&2
    exit 1
    ;;
esac
