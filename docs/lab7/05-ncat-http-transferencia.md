# Lab 7 – 3.3 Peticiones HTTP/HTTPS y transferencia con ncat

Acá van tres cosas más con ncat: una petición HTTP a `http://example.org`, la misma petición por HTTPS a `https://example.org/` y la transferencia de un `.txt` de it-01 a it-02, verificada con hash.

La idea de fondo es la misma que en los chats de [04-multihop-chat.md](04-multihop-chat.md): ncat solo abre una conexión TCP y pasa bytes. Si esos bytes son una petición HTTP bien escrita, el servidor web responde. Si son un archivo, del otro lado se guarda el archivo.

Los scripts se corren desde la laptop con Git Bash (Windows), Linux o macOS. En PowerShell, `printf` no interpreta `\r\n` igual, así que no sirve para estas pruebas. Para instalar ncat en la laptop, ver la sección "Chat local con ncat" de [04-multihop-chat.md](04-multihop-chat.md). En las instancias de TI ya queda instalado con `./lab7/ncat/chat-ti.sh instalar`.

## Petición HTTP a example.org

### Cómo funciona

```
 Laptop (o it-01)                                         example.org
┌────────────────────────────┐                          ┌──────────────┐
│ printf 'GET / HTTP/1.1...' │   TCP :80, texto plano   │ servidor web │
│   │                        │ ───── petición ────────► │              │
│   ▼                        │                          │              │
│ ncat example.org 80        │ ◄──── respuesta ──────── │ 200 OK + HTML│
└────────────────────────────┘                          └──────────────┘
```

1. `ncat example.org 80` resuelve el nombre y abre una conexión TCP al puerto 80.
2. `printf` le pasa a ncat la petición escrita a mano. ncat la manda tal cual.
3. El servidor responde con la línea de estado, las cabeceras, una línea vacía y el HTML. ncat lo imprime en la terminal.

La petición tiene tres líneas y una vacía al final:

| Línea | Para qué |
|---|---|
| `GET / HTTP/1.1` | Método, ruta y versión del protocolo |
| `Host: example.org` | Obligatoria en HTTP/1.1. Le dice al servidor qué sitio queremos, porque en la misma IP puede haber muchos (lo mismo que hace Nginx con `rrhh.barrilete.dev`) |
| `Connection: close` | Le pide al servidor que cierre al terminar de responder. Sin esto, la conexión queda abierta esperando otra petición y ncat no sale solo |
| *(línea vacía)* | Marca el fin de las cabeceras. Sin ella, el servidor se queda esperando |

Cada línea termina en `\r\n` (CRLF), como pide la RFC 9112. Por eso usamos `printf` y no `echo`.

### Comandos

```bash
./lab7/ncat/http.sh
# equivale a: printf 'GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n' | ncat example.org 80
```

Salida esperada (las fechas, `Age` y `CF-RAY` cambian cada vez):

```
== GET http://example.org/ desde <tu-equipo>
HTTP/1.1 200 OK
Date: Sun, 25 Oct 2026 01:46:58 GMT
Content-Type: text/html; charset=utf-8
Transfer-Encoding: chunked
Connection: close
Server: cloudflare
...

241
<!doctype html><html lang=en><head>...<title>Example Domain</title>...
<p>This domain is for use in documentation examples without needing permission. ...</p>...
0
```

Qué se ve ahí:

- `HTTP/1.1 200 OK`: la petición estaba bien formada y el servidor la aceptó.
- `Connection: close`: el servidor confirma que va a cerrar al terminar.
- `Transfer-Encoding: chunked`: el cuerpo viene en pedazos. El `241` es el tamaño del pedazo en hexadecimal (577 bytes) y el `0` del final marca que ya no viene nada más. Un navegador o curl lo arma solo, pero ncat nos lo muestra crudo.
- `<title>Example Domain</title>`: es la página de example.org.

### Desde it-01

Para ver que el firewall deja salir el 80 desde la subred de TI:

```bash
./lab7/ncat/http.sh it-01
```

Tiene que salir el mismo `HTTP/1.1 200 OK`. La conexión sale de it-01, pasa por el NAT del firewall (que solo deja 80, 443 e ICMP) y llega a example.org.

## Petición HTTPS a example.org

### Qué cambia

```
 Laptop (o it-01)                                         example.org
┌────────────────────────────┐                          ┌──────────────┐
│ printf 'GET / HTTP/1.1...' │   TCP :443               │              │
│   │                        │ ── 1. handshake TLS ───► │ certificado  │
│   ▼                        │ ══ 2. petición cifrada ═►│              │
│ ncat --ssl example.org 443 │ ◄═ 3. respuesta cifrada ═│ 200 OK + HTML│
└────────────────────────────┘                          └──────────────┘
```

La petición HTTP es exactamente la misma. La diferencia es `--ssl`:

1. ncat abre la conexión TCP al 443.
2. Hace el handshake TLS: negocia la versión y el cifrado, recibe el certificado del servidor y acuerdan las llaves.
3. Recién ahí manda el texto HTTP, pero adentro del canal cifrado. La respuesta también llega cifrada y ncat la descifra antes de imprimirla.

Si alguien captura el tráfico en la red, con HTTP ve la petición y el HTML en texto plano. Con HTTPS solo ve bytes cifrados y, como mucho, el nombre `example.org` (va en el SNI del handshake).

Si le mandamos la petición en texto plano al 443 (`ncat example.org 443`, sin `--ssl`), el servidor espera un handshake TLS, no entiende lo que llega y responde con error o corta la conexión.

### Comandos

```bash
./lab7/ncat/https.sh
# equivale a: printf 'GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\n\r\n' | ncat --ssl example.org 443
```

La salida es la misma que con HTTP (`HTTP/1.1 200 OK`, cabeceras, `<title>Example Domain</title>`). Eso tiene sentido: TLS cifra el transporte, pero lo que va adentro sigue siendo el mismo HTTP.

Desde it-01, para ver que el firewall deja salir el 443:

```bash
./lab7/ncat/https.sh it-01
```

### --ssl no revisa el certificado

`--ssl` cifra, pero acepta cualquier certificado, incluso uno falso o vencido. Contra un ataque de intermediario (MITM) eso no protege. Para que ncat sí lo valide:

```bash
./lab7/ncat/https.sh verificar
# equivale a: printf '...' | ncat -v --ssl --ssl-verify example.org 443
```

Con `-v`, antes de la respuesta salen líneas como estas:

```
Ncat: Version 7.9x ( https://nmap.org/ncat )
Ncat: SSL connection to <ip-de-example.org>:443.
Ncat: SHA-1 fingerprint: XXXX XXXX ...
HTTP/1.1 200 OK
...
```

Si el certificado no fuera válido para `example.org`, ncat cortaría con un error de verificación y no mandaría la petición. Un navegador hace esta revisión siempre.

## Transferencia de un .txt entre it-01 e it-02

### Cómo funciona

```
 it-01 (.138)                                             it-02 (.139)
┌──────────────────────────────┐                        ┌────────────────────────────┐
│ ncat --send-only             │   TCP 4444 (it_self)   │ ncat -l 4444 > recibido.txt│
│   192.168.10.139 4444        │ ─── bytes del .txt ──► │                            │
│   < prueba.txt               │                        │                            │
└──────────────────────────────┘                        └────────────────────────────┘
        sha256sum prueba.txt            ==             sha256sum recibido.txt
```

1. it-02 escucha en el 4444 y redirige todo lo que llega a `recibido.txt`.
2. it-01 se conecta y le pasa `prueba.txt` por la entrada estándar.
3. `--send-only` hace que it-01 solo mande (no espera nada de vuelta) y cierre la conexión al terminar el archivo. Con eso, it-02 también termina solo.
4. Calculamos el SHA-256 en los dos lados. Si un solo byte cambiara, el hash sería otro. Si coinciden, el archivo llegó completo e igual.

Igual que el chat, va en texto plano: cualquiera que capture el tráfico en la subred puede leer el archivo. Para algo sensible usaríamos `scp`, o `ncat --ssl` en los dos lados.

### Comandos

Terminal 1, crear el archivo en it-01:

```bash
./lab7/ncat/transferencia.sh preparar
```

```
-rw-r--r--. 1 ec2-user ec2-user 211 Oct 24 19:50 prueba.txt
Lab 7 CC3067 - transferencia con ncat
Origen: ip-192-168-10-138.ec2.internal (192.168.10.138)
Destino: it-02 (192.168.10.139), puerto 4444
Fecha: 2026-10-24 19:50:12 UTC
Barrilete Ventures - barrilete.dev
```

El tamaño y la fecha pueden variar.

Terminal 1, poner a it-02 a escuchar:

```bash
./lab7/ncat/transferencia.sh recibir
# ssh -t it-02 "ncat -l 4444 > recibido.txt"
```

Terminal 2, mandar el archivo desde it-01:

```bash
./lab7/ncat/transferencia.sh enviar
# ssh it-01 "ncat --send-only 192.168.10.139 4444 < prueba.txt"
```

```
it-01 mandando prueba.txt a 192.168.10.139:4444
enviado
```

En la terminal 1, ncat termina solo y aparece el archivo:

```
-rw-r--r--. 1 ec2-user ec2-user 211 Oct 24 19:50 recibido.txt
```

### Verificar con el hash

```bash
./lab7/ncat/transferencia.sh verificar
```

```
it-01: 3f9a...c41e  prueba.txt
it-02: 3f9a...c41e  recibido.txt
OK: los hashes coinciden, el archivo llegó completo
```

El hash completo son 64 caracteres hexadecimales. Lo importante es que sea igual en las dos líneas. A mano sería `sha256sum prueba.txt` en it-01 y `sha256sum recibido.txt` en it-02.

### Cerrar y limpiar

```bash
./lab7/ncat/transferencia.sh limpiar
```

```
== it-01
nadie escucha en el 4444
== it-02
nadie escucha en el 4444
```

Borra los dos `.txt` y revisa que ya nadie esté escuchando en el 4444.

## Hardening

- Las peticiones HTTP y HTTPS salen por el 80 y el 443, que el firewall ya dejaba salir. No abrimos nada nuevo.
- La transferencia usa solo el TCP 4444 entre it-01 e it-02, con la regla `it_self` del SG de TI. Desde Ventas no se llega (ver la prueba de [04-multihop-chat.md](04-multihop-chat.md)).
- ncat solo escucha mientras dura la prueba. Al terminar, `limpiar` confirma que el 4444 quedó cerrado.

## Fuentes

- RFC 9110, *HTTP Semantics*: métodos, códigos de estado y cabecera `Host`. <https://www.rfc-editor.org/rfc/rfc9110>
- RFC 9112, *HTTP/1.1*: formato del mensaje, CRLF, `Connection: close` y `Transfer-Encoding: chunked` (§7.1). <https://www.rfc-editor.org/rfc/rfc9112>
- RFC 8446, *TLS 1.3*: handshake. <https://www.rfc-editor.org/rfc/rfc8446>
- Guía de Ncat: `--ssl`, `--ssl-verify`, `--send-only` y transferencia de archivos. <https://nmap.org/ncat/guide/>

## Capturas (en `evidencias/lab7/`)

| Archivo | Qué se ve |
|---|---|
| `http-01-laptop.png` | `./lab7/ncat/http.sh` con `HTTP/1.1 200 OK`, las cabeceras y `<title>Example Domain</title>` |
| `http-02-it01.png` | `./lab7/ncat/http.sh it-01` con el mismo `200 OK` desde la subred de TI |
| `https-01-laptop.png` | `./lab7/ncat/https.sh` con `HTTP/1.1 200 OK` y `<title>Example Domain</title>` |
| `https-02-it01.png` | `./lab7/ncat/https.sh it-01` con el `200 OK` desde la subred de TI |
| `https-03-verificar.png` | `./lab7/ncat/https.sh verificar` con `SSL connection to ...` y la huella del certificado |
| `transferencia-01-preparar.png` | `transferencia.sh preparar` con el contenido de `prueba.txt` |
| `transferencia-02-recibir-enviar.png` | Las dos terminales lado a lado: `recibir` en it-02 y `enviar` en it-01, con `enviado` y el `ls -l recibido.txt` |
| `transferencia-03-sha256.png` | `transferencia.sh verificar` con los dos hashes iguales y `OK` |
| `transferencia-04-limpiar.png` | `transferencia.sh limpiar` con "nadie escucha en el 4444" en las dos |
