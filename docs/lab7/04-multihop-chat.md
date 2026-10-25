# Lab 7 – 3.2 Multi-hop y 3.3 chats con ncat

Acá van tres cosas: llegar a it-02 saltando por el Bastion y por it-01 (multi-hop), un chat con ncat en local y otro chat con ncat entre las dos instancias de TI.

Todo usa los hosts `bastion` e `it-01` de [`lab7/ssh_config.example`](../../lab7/ssh_config.example) (ver [01-conexion.md](01-conexion.md)). No tocamos Terraform: el SG `it_self` del Bloque A ya deja pasar TCP 22 y TCP 4444 entre it-01 e it-02, y nada más.

## Multi-hop: laptop → Bastion → it-01 → it-02

### Cómo funciona

```
 Laptop                 Bastion (.180)          it-01 (.138)            it-02 (.139)
┌────────────┐  SSH :22 ┌──────────────┐ SSH :22 ┌──────────────┐ SSH :22 ┌──────────────┐
│ ssh -J     │═════════►│ salto 1      │════════►│ salto 2      │════════►│ sshd         │
│ llave .pem │ Internet │ (SG bastion) │ VPC     │ (SG it)      │ it_self │ $SSH_CONN... │
└────────────┘          └──────────────┘         └──────────────┘         │ = .138 ...   │
                                                                          └──────────────┘
```

Cada salto es una conexión TCP nueva que sale del host anterior, pero la autenticación SSH siempre la hace la laptop. it-01 solo reenvía bytes cifrados y nunca ve la llave ni lo que escribimos en it-02.

El último tramo (it-01 → it-02 por el 22) solo existe gracias a `it_self`. Antes del Bloque A, TI solo aceptaba SSH desde el Bastion.

### Variante 1: `ssh -J`

```bash
./lab7/tuneles/multihop.sh jump
# equivale a: ssh -i ~/.ssh/barrillete-key.pem -J bastion,it-01 ec2-user@192.168.10.139
```

Ya dentro de it-02:

```bash
hostname; hostname -I; echo $SSH_CONNECTION
```

```
ip-192-168-10-139.ec2.internal
192.168.10.139
192.168.10.138 51234 192.168.10.139 22
```

La clave está en `$SSH_CONNECTION`: el primer campo es la IP de quien abrió la conexión, y es it-01 (`.138`), no el Bastion (`.180`). Eso prueba que el último salto salió de it-01. El puerto de origen (51234) cambia cada vez.

`-J` acepta varios saltos separados por coma y los recorre en orden. Para `bastion` e `it-01` toma la config del `~/.ssh/config`; el destino va por IP, por eso le pasamos la llave con `-i`.

### Variante 2: túneles -L encadenados (el salto a mano)

Esta es la idea de la referencia del enunciado, pero armando cada salto nosotros. Se usan tres terminales en la laptop:

```
 Terminal 1: localhost:2201 ══► bastion ──► it-01:22
 Terminal 2: localhost:2202 ══► (por 2201) it-01 ──► it-02:22
 Terminal 3: ssh -p 2202 localhost  =  sesión en it-02
```

Terminal 1, primer túnel (laptop → it-01 a través del Bastion):

```bash
./lab7/tuneles/multihop.sh salto1
# ssh -N -o ExitOnForwardFailure=yes -L 2201:192.168.10.138:22 bastion
```

Terminal 2, segundo túnel (desde it-01 hacia it-02):

```bash
./lab7/tuneles/multihop.sh salto2
# ssh -N -o ExitOnForwardFailure=yes -o HostKeyAlias=192.168.10.138 \
#     -i ~/.ssh/barrillete-key.pem -p 2201 -L 2202:192.168.10.139:22 ec2-user@localhost
```

Esta sesión entra a it-01 por el túnel de la terminal 1. Su `-L` le pide a **it-01** que abra la conexión a `192.168.10.139:22`, así que el segundo túnel sale desde it-01, igual que en la referencia. `HostKeyAlias` hace que ssh compare la huella con la de it-01 y no con la de `localhost`.

Terminal 3, entrar a it-02:

```bash
./lab7/tuneles/multihop.sh entrar 'hostname; echo $SSH_CONNECTION'
```

```
ip-192-168-10-139.ec2.internal
192.168.10.138 51240 192.168.10.139 22
```

Otra vez sale `.138`: it-02 ve la conexión como si viniera de it-01.

En la referencia, el segundo `ssh -L` se corre adentro de it-01. Nosotros lo corremos desde la laptop y por el primer túnel, con el mismo resultado. Así no hace falta copiar el `.pem` a it-01 ni usar `ssh -A` (agent forwarding), porque cualquiera con root en it-01 podría usar nuestra llave mientras la sesión esté abierta.

### Cerrar los túneles

Ctrl+C en las terminales 2 y 1, en ese orden. Para confirmar que no quedó nada escuchando:

```bash
# Linux / macOS / Git Bash
ss -tln | grep -E ':220[12] ' || echo "sin túneles"
# Windows PowerShell
netstat -ano | findstr ":2201 :2202"
```

Si no sale nada (o sale `sin túneles`), está limpio.

## Chat local con ncat

ncat escucha en un puerto (`-l`) o se conecta a uno. Lo que entra por el teclado se manda por TCP y lo que llega se imprime. Es el chat más básico posible y va en texto plano, sin cifrar.

Instalación local: en Linux `sudo dnf install -y nmap-ncat` (o `apt install ncat`), en macOS `brew install nmap` y en Windows el instalador de [Nmap](https://nmap.org/download), que trae `ncat.exe`.

### Dos terminales en la misma laptop

```bash
# Terminal 1
./lab7/ncat/chat-local.sh servidor          # ncat -l 4444
# Terminal 2
./lab7/ncat/chat-local.sh cliente 127.0.0.1 # ncat 127.0.0.1 4444
```

### Dos laptops en la misma red

En la laptop A, sacá la IP con `ip -4 addr` (Linux), `ipconfig getifaddr en0` (macOS) o `ipconfig` (Windows), y corré el servidor. En la laptop B, el cliente con esa IP:

```bash
./lab7/ncat/chat-local.sh servidor           # laptop A
./lab7/ncat/chat-local.sh cliente 10.0.0.25  # laptop B, con la IP de A
```

En Windows, la primera vez sale el aviso del Firewall de Windows para `ncat.exe`. Permitilo solo en redes **privadas**. Si la red de la U aísla a los clientes entre sí, usen el hotspot de un celular.

### Salida esperada

Lo que se escribe en un lado aparece tal cual en el otro:

```
Terminal 1 (servidor)          Terminal 2 (cliente)
Escuchando chat en el 4444     Conectando a 127.0.0.1:4444
hola desde B                   hola desde B          ← escrito en 2
qué onda, acá A                qué onda, acá A       ← escrito en 1
```

`ncat -l` atiende a un solo cliente: cuando el cliente se va (Ctrl+C), el servidor también termina.

## Chat entre it-01 e it-02

Mismo chat, pero entre las instancias de TI. it-02 escucha en el 4444 e it-01 se conecta. Lo manejamos todo desde la laptop por SSH.

```
 Laptop ─ssh─► it-02: ncat -l 4444  ◄──── TCP 4444 (it_self) ────  it-01: ncat 192.168.10.139 4444 ◄─ssh─ Laptop
```

### Instalar ncat (una sola vez)

```bash
./lab7/ncat/chat-ti.sh instalar
# en cada una: sudo dnf install -y nmap-ncat && ncat --version
```

```
== it-01
...
Complete!
Ncat: Version 7.93 ( https://nmap.org/ncat )
== it-02
...
```

La versión puede cambiar. dnf descarga por HTTPS (443), que el firewall sí deja salir desde las subredes privadas.

### Chat

```bash
# Terminal 1
./lab7/ncat/chat-ti.sh servidor   # ssh -t it-02 "ncat -l 4444"
# Terminal 2
./lab7/ncat/chat-ti.sh cliente    # ssh -t it-01 "ncat 192.168.10.139 4444"
```

Escriban algo en cada terminal (por ejemplo `hola desde it-01` y `recibido, acá it-02`) y tiene que aparecer del otro lado, igual que en el chat local.

Para comprobar que la conexión de verdad va de it-01 a it-02, abran una tercera terminal con el chat abierto:

```bash
ssh it-02 "ss -tn | grep ':4444'"
```

```
ESTAB 0 0 192.168.10.139:4444 192.168.10.138:40122
```

### Que solo TI llegue al 4444

La regla `it_self` abre el 4444 solo para el SG de TI. Con it-02 escuchando, desde Ventas no se llega:

```bash
ssh -J bastion ec2-user@192.168.10.10 'timeout 5 bash -c "</dev/tcp/192.168.10.139/4444" && echo abierto || echo bloqueado'
# bloqueado
```

### Cerrar

Ctrl+C en las dos terminales y después:

```bash
./lab7/ncat/chat-ti.sh verificar
```

```
== it-01
nadie escucha en el 4444
== it-02
nadie escucha en el 4444
```

## Capturas (en `evidencias/lab7/`)

| Archivo | Qué se ve |
|---|---|
| `multihop-01-jump.png` | `./lab7/tuneles/multihop.sh jump` y en it-02 `hostname; hostname -I; echo $SSH_CONNECTION` con `192.168.10.138` |
| `multihop-02-salto1.png` | Terminal 1 con `multihop.sh salto1` corriendo |
| `multihop-03-salto2.png` | Terminal 2 con `multihop.sh salto2` corriendo |
| `multihop-04-entrar-it02.png` | Terminal 3 con `multihop.sh entrar ...` mostrando `ip-192-168-10-139` y `192.168.10.138` en `$SSH_CONNECTION` |
| `multihop-05-cerrados.png` | `ss -tln` o `netstat` sin 2201 ni 2202 después de Ctrl+C |
| `chat-local-01-servidor.png` | Terminal (o laptop A) con `chat-local.sh servidor` y los mensajes |
| `chat-local-02-cliente.png` | Terminal (o laptop B) con `chat-local.sh cliente <ip>` y los mismos mensajes |
| `chat-ti-01-instalar.png` | `chat-ti.sh instalar` con `Complete!` y `ncat --version` en las dos |
| `chat-ti-02-conversacion.png` | Las dos terminales lado a lado: it-02 escuchando e it-01 conectado, con los mensajes |
| `chat-ti-03-ss-estab.png` | `ss -tn` en it-02 con `ESTAB ... 192.168.10.138` |
| `chat-ti-04-ventas-bloqueado.png` | Prueba del 4444 desde Ventas → `bloqueado` |
| `chat-ti-05-cerrado.png` | `chat-ti.sh verificar` con "nadie escucha en el 4444" en las dos |
