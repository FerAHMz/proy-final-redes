#!/bin/bash
# Lab 7 – 3.3 Transferencia de un .txt de it-01 a it-02 con ncat.
#
# it-02 escucha en el 4444 y guarda en recibido.txt todo lo que le llegue.
# it-01 se conecta y manda prueba.txt. Con --send-only, it-01 cierra la
# conexión apenas termina de mandar el archivo, e it-02 termina solo.
# Después comparamos el sha256 de los dos lados: si coincide, el archivo llegó
# completo y sin cambios.
#
# Usa el TCP 4444 que el SG it_self abre solo entre instancias de TI y los hosts
# it-01 / it-02 de lab7/ssh_config.example. ncat ya tiene que estar instalado
# (./lab7/ncat/chat-ti.sh instalar).
#
# Uso:
#   ./lab7/ncat/transferencia.sh preparar    # crea prueba.txt en it-01
#   ./lab7/ncat/transferencia.sh recibir     # terminal 1: it-02 escucha en el 4444
#   ./lab7/ncat/transferencia.sh enviar      # terminal 2: it-01 manda prueba.txt
#   ./lab7/ncat/transferencia.sh verificar   # sha256sum en los dos lados
#   ./lab7/ncat/transferencia.sh limpiar     # borra los .txt y revisa el 4444
#
# A mano, sin el script:
#   it-02$ ncat -l 4444 > recibido.txt
#   it-01$ ncat --send-only 192.168.10.139 4444 < prueba.txt
#   it-01$ sha256sum prueba.txt
#   it-02$ sha256sum recibido.txt
set -euo pipefail

IT02=192.168.10.139
PUERTO=4444

case "${1:-}" in
  preparar)
    ssh it-01 'cat > prueba.txt <<EOF
Lab 7 CC3067 - transferencia con ncat
Origen: $(hostname) ($(hostname -I | xargs))
Destino: it-02 (192.168.10.139), puerto 4444
Fecha: $(date "+%Y-%m-%d %H:%M:%S %Z")
Barrilete Ventures - barrilete.dev
EOF
ls -l prueba.txt && cat prueba.txt'
    ;;
  recibir)
    echo "it-02 esperando el archivo en el $PUERTO (termina solo al recibirlo)"
    # -t: si hay que cortar con Ctrl+C, ncat se cierra en it-02 y no queda colgado
    ssh -t it-02 "ncat -l $PUERTO > recibido.txt && ls -l recibido.txt"
    ;;
  enviar)
    echo "it-01 mandando prueba.txt a $IT02:$PUERTO"
    ssh it-01 "ncat --send-only $IT02 $PUERTO < prueba.txt && echo 'enviado'"
    ;;
  verificar)
    origen=$(ssh it-01 'sha256sum prueba.txt')
    destino=$(ssh it-02 'sha256sum recibido.txt')
    echo "it-01: $origen"
    echo "it-02: $destino"
    if [ "${origen%% *}" = "${destino%% *}" ]; then
      echo "OK: los hashes coinciden, el archivo llegó completo"
    else
      echo "ERROR: los hashes no coinciden" >&2
      exit 1
    fi
    ;;
  limpiar)
    ssh it-01 'rm -f prueba.txt'
    ssh it-02 'rm -f recibido.txt'
    for host in it-01 it-02; do
      echo "== $host"
      ssh "$host" "ss -tln | grep ':$PUERTO ' || echo 'nadie escucha en el $PUERTO'"
    done
    ;;
  *)
    echo "Uso: $0 {preparar|recibir|enviar|verificar|limpiar}" >&2
    exit 1
    ;;
esac
