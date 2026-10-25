#!/bin/bash
# Lab 7 – 3.2 Túnel multi-hop: laptop → Bastion → it-01 → it-02.
#
# it-02 no tiene IP pública y desde Internet solo se entra por el Bastion. Acá
# llegamos a it-02 pasando también por it-01, para que el último salto sea
# entre las dos instancias de TI (SG it_self, TCP 22).
#
# Dos variantes:
#   jump   → ssh -J bastion,it-01: ssh arma los saltos solo
#   salto1 / salto2 / entrar → los mismos saltos a mano con -L encadenados
#
# En las dos, la llave se queda en la laptop. Ninguna instancia guarda el .pem.
#
# Antes de correrlo:
#   1. Tener `bastion` e `it-01` en ~/.ssh/config (ver lab7/ssh_config.example)
#   2. Si tu llave no está en ~/.ssh/barrillete-key.pem: export LLAVE=/ruta/a/la.pem
#
# Uso:
#   ./lab7/tuneles/multihop.sh jump [comando]   # shell en it-02 (o corre el comando)
#
#   ./lab7/tuneles/multihop.sh salto1           # terminal 1: localhost:2201 → it-01:22
#   ./lab7/tuneles/multihop.sh salto2           # terminal 2: localhost:2202 → it-02:22, saliendo de it-01
#   ./lab7/tuneles/multihop.sh entrar [comando] # terminal 3: ssh a it-02 por localhost:2202
#
# Para ver desde dónde llegó la conexión, en it-02:
#   echo $SSH_CONNECTION   → empieza con 192.168.10.138 (it-01), no con el Bastion
set -euo pipefail

IT01=192.168.10.138
IT02=192.168.10.139
LLAVE="${LLAVE:-$HOME/.ssh/barrillete-key.pem}"

modo="${1:-}"
shift || true

case "$modo" in
  jump)
    echo "Multi-hop: laptop -> bastion -> it-01 -> it-02 ($IT02)"
    # -J acepta varios saltos separados por coma; bastion e it-01 salen del ~/.ssh/config.
    # El destino va por IP, así que su llave hay que pasarla con -i.
    ssh -i "$LLAVE" -J bastion,it-01 "ec2-user@$IT02" "$@"
    ;;
  salto1)
    echo "Salto 1: localhost:2201 -> bastion -> it-01:22 (Ctrl+C para cerrar)"
    # Igual que el túnel local del Bloque B, pero el destino es el SSH de it-01
    ssh -N -o ExitOnForwardFailure=yes -L "2201:$IT01:22" bastion
    ;;
  salto2)
    echo "Salto 2: localhost:2202 -> (por el salto 1) it-01 -> it-02:22 (Ctrl+C para cerrar)"
    # Esta sesión SSH entra a it-01 por el túnel del salto 1, y el -L hace que
    # sea it-01 quien abra la conexión a it-02:22.
    # HostKeyAlias: la huella que se compara es la de it-01 y no la de "localhost"
    ssh -N -o ExitOnForwardFailure=yes -o HostKeyAlias="$IT01" \
        -i "$LLAVE" -p 2201 -L "2202:$IT02:22" ec2-user@localhost
    ;;
  entrar)
    echo "Entrando a it-02 por localhost:2202"
    ssh -o HostKeyAlias="$IT02" -i "$LLAVE" -p 2202 ec2-user@localhost "$@"
    ;;
  *)
    echo "Uso: $0 {jump|salto1|salto2|entrar} [comando]" >&2
    exit 1
    ;;
esac
