# Lab 7 CC3067 – Túneles SSH y ncat

Todo el Lab 7 sobre la red del proyecto en AWS: dos instancias en TI con acceso por llaves, los tres tipos de túnel SSH, un multi-hop y varias pruebas con ncat. Cada actividad tiene su script en [`lab7/`](../../lab7) y su explicación acá.

## Índice

| Doc | Enunciado | Qué tiene | Scripts |
|---|---|---|---|
| [01-conexion.md](01-conexion.md) | 3.1 | it-02 con Terraform, permisos de la llave (`chmod 400` / `icacls`) y conexión por llaves con ProxyJump | [`ssh_config.example`](../../lab7/ssh_config.example) |
| [02-local-reverse.md](02-local-reverse.md) | 3.2 | Túnel local (-L) a la intranet de RRHH y reverse (-R) de la laptop al Bastion, con casos de uso | [`local.sh`](../../lab7/tuneles/local.sh), [`reverse.sh`](../../lab7/tuneles/reverse.sh) |
| [03-dynamic.md](03-dynamic.md) | 3.2 | Modo dynamic (-D) como proxy SOCKS, socks5 vs socks5h, casos de uso y las preguntas sobre SOCKS | [`dynamic.sh`](../../lab7/tuneles/dynamic.sh) |
| [04-multihop-chat.md](04-multihop-chat.md) | 3.2 y 3.3 | Multi-hop it-01 → it-02 (con `-J` y con `-L` encadenados), chat local y chat entre TI con ncat | [`multihop.sh`](../../lab7/tuneles/multihop.sh), [`chat-local.sh`](../../lab7/ncat/chat-local.sh), [`chat-ti.sh`](../../lab7/ncat/chat-ti.sh) |
| [05-ncat-http-transferencia.md](05-ncat-http-transferencia.md) | 3.3 | Peticiones HTTP y HTTPS a example.org y transferencia de un .txt verificada con sha256 | [`http.sh`](../../lab7/ncat/http.sh), [`https.sh`](../../lab7/ncat/https.sh), [`transferencia.sh`](../../lab7/ncat/transferencia.sh) |

## Orden para correr todo

1. `terraform apply` y conexión por llaves (01).
2. Túneles local, reverse y dynamic (02 y 03). Uno a la vez y cerrando cada uno antes del siguiente.
3. Multi-hop y `./lab7/ncat/chat-ti.sh instalar`, que deja ncat en it-01 e it-02 (04).
4. Chats, peticiones HTTP/HTTPS y transferencia (04 y 05).
5. Verificar que no quedó nada abierto y correr `./scripts/smoke-tests.sh`.

Cada doc trae al final su tabla de capturas con el nombre exacto del archivo. Todas van en `evidencias/lab7/`.

## Cobertura del enunciado

| # | Enunciado | Doc | Capturas en `evidencias/lab7/` |
|---|---|---|---|
| 3.1 | Dos instancias Linux en TI (it-01 e it-02) | 01 | `01-terraform-apply-it02.png`, `02-consola-instancias-ti.png` |
| 3.1 | Conexión desde las laptops por SSH con llaves, no desde la consola de AWS | 01 | `04-ssh-it01.png`, `05-ssh-it02.png`, `06-ssh-publickey.png` |
| 3.1 | Permisos de lectura de la llave privada | 01 | `03-permisos-llave.png` |
| 3.2 | Túnel local (-L) | 02 | `local-01` a `local-06` |
| 3.2 | Túnel reverse (-R) | 02 | `reverse-01` a `reverse-04` |
| 3.2 | Modo dynamic / SOCKS (-D) | 03 | `dynamic-01` a `dynamic-08` |
| 3.2 | Caso académico y comercial justificados para -L, -R y -D | 02, 03 | — |
| 3.2 | ¿En qué capa funciona SOCKS? | 03 | — |
| 3.2 | Diferencia entre proxy SOCKS y proxy HTTP | 03 | — |
| 3.2 | Túnel multi-hop entre las dos instancias de TI | 04 | `multihop-01` a `multihop-04` |
| 3.3 | Chat con ncat entre dos equipos locales o dos terminales | 04 | `chat-local-01`, `chat-local-02` |
| 3.3 | Chat con ncat entre las dos instancias de TI | 04 | `chat-ti-01` a `chat-ti-04` |
| 3.3 | Petición HTTP a http://example.org | 05 | `http-01-laptop.png`, `http-02-it01.png` |
| 3.3 | Petición HTTPS a https://example.org/ | 05 | `https-01` a `https-03` |
| 3.3 | Transferencia de un .txt entre las instancias de TI, verificada con hash | 05 | `transferencia-01` a `transferencia-04` |
| — | Túneles y puertos cerrados después de las pruebas | 02 a 05 | `tuneles-cerrados.png`, `dynamic-09`, `multihop-05`, `chat-ti-05`, `transferencia-04` |
| — | Smoke tests de la Fase 2 (Ventas no llega a TI) | 01 | `07-smoke-tests.png`, `08-ventas-no-llega-ti-4444.png` |

## Hardening

Para el lab solo abrimos lo mínimo:

- TCP 22 y TCP 4444 entre instancias del SG de TI (regla `it_self`). Nada más se agregó a los SG ni al firewall.
- Todos los túneles viajan dentro del 22 del Bastion, que sigue limitado a `admin_cidr`, y escuchan solo en loopback.
- Las peticiones a example.org salen por 80 y 443, que el firewall ya permitía.
