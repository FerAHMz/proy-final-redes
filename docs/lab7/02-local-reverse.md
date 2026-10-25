# Lab 7 – 3.2 Túneles local (-L) y reverse (-R)

Un túnel SSH mete una conexión TCP adentro de la sesión SSH que ya tenemos con el Bastion. Desde fuera solo se ve tráfico cifrado al puerto 22, y no hace falta abrir ningún puerto nuevo en los Security Groups ni en el firewall.

- **Local (-L):** la laptop escucha un puerto y lo que entra ahí sale *desde el servidor SSH* hacia un destino. Sirve para alcanzar algo que solo existe del otro lado.
- **Reverse (-R):** al revés. El servidor SSH escucha un puerto y lo que entra ahí sale *desde la laptop*. Sirve para que el otro lado alcance algo que solo existe en la laptop.

Los dos usan el host `bastion` de [`lab7/ssh_config.example`](../../lab7/ssh_config.example) (ver [01-conexion.md](01-conexion.md)).

## Túnel local: la intranet de RRHH desde la laptop

### Cómo funciona

```
 Laptop                              Bastion (.180)                 dc-01 (.164)
┌──────────────────────┐           ┌──────────────────┐           ┌──────────────┐
│ navegador / curl     │           │ sshd             │           │ Nginx :80    │
│   │                  │  SSH :22  │   │              │  TCP :80  │ server_name  │
│   ▼                  │ (cifrado) │   ▼              │ (en VPC)  │ rrhh.        │
│ 127.0.0.1:8080 ══════╪═══════════╪═► resuelve       ├──────────►│ barrilete.dev│
│ (ssh -L)             │           │  rrhh.barrilete. │           │              │
└──────────────────────┘           │  dev → .164      │           └──────────────┘
                                   └──────────────────┘
```

1. `ssh -L 8080:rrhh.barrilete.dev:80 bastion` hace que la laptop escuche en `127.0.0.1:8080`.
2. Cuando el navegador se conecta ahí, ssh le pide al Bastion por el canal cifrado que abra una conexión a `rrhh.barrilete.dev:80`.
3. El nombre lo resuelve el **Bastion** con la zona privada de Route 53, porque desde Internet `barrilete.dev` no existe. El SG `web` ya deja entrar HTTP desde el SG del Bastion, así que no tocamos Terraform.
4. El tramo Bastion → dc-01 va en HTTP plano, pero dentro de la VPC. Lo que cruza Internet va cifrado por SSH.

### El detalle del archivo hosts

Nginx en dc-01 solo responde si la cabecera `Host` dice `rrhh.barrilete.dev`. Si la petición llega por IP o con otro nombre, cae en el `default_server` y hace `return 444`: cierra la conexión sin mandar nada.

Si entramos a `http://localhost:8080`, el navegador manda `Host: localhost:8080` y Nginx corta. Para que mande el nombre correcto, hacemos que `rrhh.barrilete.dev` apunte a la laptop:

| Sistema | Archivo (con permisos de admin) |
|---|---|
| Linux / macOS | `/etc/hosts` |
| Windows | `C:\Windows\System32\drivers\etc\hosts` (abrir el Bloc de notas como administrador) |

Línea que se agrega:

```
127.0.0.1 rrhh.barrilete.dev
```

Ahora `http://rrhh.barrilete.dev:8080` va a `127.0.0.1:8080`, entra al túnel y llega con `Host: rrhh.barrilete.dev:8080`. Nginx compara `server_name` sin el puerto, así que la acepta.

### Comandos

Terminal 1 (deja el túnel abierto):

```bash
./lab7/tuneles/local.sh
# equivale a: ssh -N -o ExitOnForwardFailure=yes -L 8080:rrhh.barrilete.dev:80 bastion
```

`-N` evita que se abra una shell en el Bastion. Sin `-N` (`ssh -L 8080:rrhh.barrilete.dev:80 bastion`) funciona igual, pero además te deja una sesión abierta en el Bastion.

Terminal 2:

```bash
# 1. Por nombre: la intranet responde
curl -s http://rrhh.barrilete.dev:8080 | grep -E "<title>|<h1>"
```

```
  <title>Barrilete People</title>
      <h1>Bienvenido a la intranet de Recursos Humanos</h1>
```

```bash
# 2. Por localhost: Nginx descarta la petición (444). Esto prueba que el túnel
#    sí llega a dc-01 y que la regla de "solo por nombre" sigue funcionando.
curl -v http://localhost:8080/
```

```
* Connected to localhost (127.0.0.1) port 8080
> GET / HTTP/1.1
> Host: localhost:8080
...
* Empty reply from server
curl: (52) Empty reply from server
```

```bash
# 3. El túnel escucha solo en loopback
ss -tln | grep 8080              # Linux/macOS: 127.0.0.1:8080 y [::1]:8080
netstat -ano | findstr :8080     # Windows: 127.0.0.1:8080 LISTENING
```

Por último, abrir `http://rrhh.barrilete.dev:8080` en el navegador y ver la página de Barrilete People.

Truco: sin tocar el archivo hosts también se puede probar con `curl -H "Host: rrhh.barrilete.dev" http://localhost:8080/`. Para el navegador sí hace falta la línea en hosts.

## Túnel reverse: la laptop vista desde el Bastion

### Cómo funciona

```
 Laptop (detrás de NAT)                       Bastion (.180)
┌──────────────────────────┐               ┌────────────────────────┐
│ python3 -m http.server   │               │                        │
│ 127.0.0.1:8000 ◄─────┐   │   SSH :22     │  curl localhost:9090   │
│                      │   │  (la laptop   │        │               │
│              ssh -R ═╪═══╪═══ abre la ═══╪══► 127.0.0.1:9090      │
│                          │   conexión)   │  (lo escucha sshd)     │
└──────────────────────────┘               └────────────────────────┘
```

1. En la laptop corre un servidor web en `127.0.0.1:8000`.
2. `ssh -R 9090:localhost:8000 bastion` le pide al sshd del Bastion que escuche en su `localhost:9090`.
3. Cuando algo en el Bastion se conecta al 9090, sshd lo manda por el canal cifrado a la laptop, y ssh lo entrega a `localhost:8000`.
4. La conexión SSH la abre la laptop hacia afuera, por eso funciona aunque la laptop esté detrás del NAT de la casa o de la U.

### Por qué queda solo en localhost del Bastion

- `GatewayPorts` en el sshd del Bastion queda en su valor por defecto (`no`), así que sshd fuerza el bind del `-R` a loopback, aunque alguien pida `-R 0.0.0.0:9090:...`.
- No pusimos `bind_address` en el `-R`.
- Aunque estuviera abierto, el SG del Bastion solo deja entrar el 22 desde `admin_cidr`.
- El servidor de Python se levanta con `--bind 127.0.0.1`, así que tampoco queda expuesto a la red local de la laptop.

### Comandos

Terminal 1 (laptop):

```bash
./lab7/tuneles/reverse.sh
```

El script hace esto:

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory <carpeta temporal con index.html>
ssh -N -o ExitOnForwardFailure=yes -R 9090:localhost:8000 bastion
```

Terminal 2 (desde la laptop, ejecutando en el Bastion):

```bash
ssh bastion 'curl -s localhost:9090'
```

```
<h1>Hola desde la laptop de <tu-usuario></h1>
<p>Esto lo sirve <nombre-de-tu-equipo> y llegó al Bastion por un túnel ssh -R.</p>
```

En la terminal 1 aparece el log del servidor de Python con la petición:

```
127.0.0.1 - - [24/Oct/2026 18:30:12] "GET / HTTP/1.1" 200 -
```

```bash
# El 9090 escucha solo en loopback del Bastion
ssh bastion 'ss -tln | grep 9090'
```

```
LISTEN 0  128   127.0.0.1:9090   0.0.0.0:*
LISTEN 0  128       [::1]:9090      [::]:*
```

```bash
# Desde otra instancia (it-01) no se llega al 9090 del Bastion
ssh it-01 'timeout 5 bash -c "</dev/tcp/192.168.10.180/9090" && echo abierto || echo bloqueado'
```

```
bloqueado
```

## Cerrar los túneles

- **Ctrl+C** en la terminal del túnel. En `reverse.sh` también se apaga el servidor de Python y se borra la carpeta temporal.
- Si la sesión se quedó colgada: Enter, luego `~.` (secuencia de escape de ssh).
- Si se abrió en segundo plano con `-f`:

```bash
pkill -f "ssh .*-L 8080"                        # Linux/macOS
pkill -f "ssh .*-R 9090"
```

```powershell
Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" | Where-Object CommandLine -match "8080|9090" | ForEach-Object { Stop-Process -Id $_.ProcessId }
```

Verificar que no quedó nada abierto (lo pide el checklist final):

```bash
ss -tln | grep -E ':8080|:9090' || echo "sin túneles en la laptop"
netstat -ano | findstr ":8080 :9090"            # Windows: no debe salir nada
ssh bastion 'ss -tln | grep :9090 || echo "sin túneles en el Bastion"'
```

Y quitar la línea `127.0.0.1 rrhh.barrilete.dev` del archivo hosts.

## Casos de uso

### Túnel local (-L)

**Académico:** el laboratorio de la U tiene un servidor con Jupyter o una base de datos para los cursos, y solo escucha dentro de la red del campus. Desde la casa, con `ssh -L 8888:localhost:8888 usuario@servidor-lab`, el estudiante abre `localhost:8888` y trabaja como si estuviera en el lab.

*Justificación:* el servicio sigue sin estar expuesto a Internet (solo el 22 con llave), no hace falta una VPN para cada estudiante y el tráfico va cifrado aunque Jupyter use HTTP plano.

**Comercial:** una base de datos PostgreSQL (por ejemplo RDS) vive en una subred privada sin IP pública. Un developer o el equipo de soporte la consulta con `ssh -L 5432:db.interna:5432 bastion` y usa su cliente de siempre (DBeaver, psql) contra `localhost:5432`. Es lo mismo que hicimos con la intranet de RRHH.

*Justificación:* el 5432 nunca se abre a Internet, el acceso queda centralizado en el Bastion (llaves, logs, `admin_cidr`) y quitarle el acceso a alguien es tan simple como borrar su llave.

### Túnel reverse (-R)

**Académico:** en un proyecto con una Raspberry Pi o una laptop que está en la red de la U o en la casa de un compañero (detrás de NAT, sin IP pública), el equipo hace `ssh -R 2222:localhost:22 servidor-del-curso`. El resto del grupo o el catedrático entra con `ssh -p 2222 localhost` desde el servidor del curso para revisar o calificar.

*Justificación:* no hay que pedirle a TI de la U ni al ISP de la casa que abran puertos o hagan port forwarding en el router. La conexión sale desde adentro, algo que casi cualquier red permite.

**Comercial:** una empresa de rastreo GPS o de puntos de venta tiene equipos instalados donde el cliente, detrás de NAT o CGNAT del ISP. Cada equipo mantiene un `ssh -R` hacia un servidor de soporte de la empresa, y el técnico entra a dar mantenimiento sin ir al sitio. Otro caso común es exponer el servidor local de desarrollo para recibir webhooks (pagos, GitHub), que es lo que hacen herramientas como ngrok.

*Justificación:* el cliente no tiene que tocar su firewall, el canal va cifrado y autenticado con llave, y si se limita a localhost del servidor de soporte (sin `GatewayPorts`), solo el personal autorizado lo puede usar.

## Capturas (en `evidencias/lab7/`)

| Archivo | Qué se ve |
|---|---|
| `local-01-archivo-hosts.png` | Archivo hosts con la línea `127.0.0.1 rrhh.barrilete.dev` |
| `local-02-tunel-abierto.png` | Terminal 1 con `./lab7/tuneles/local.sh` corriendo |
| `local-03-curl-por-nombre.png` | `curl -s http://rrhh.barrilete.dev:8080 \| grep -E "<title>\|<h1>"` con Barrilete People |
| `local-04-navegador-rrhh.png` | Navegador en `http://rrhh.barrilete.dev:8080` con la intranet |
| `local-05-curl-444.png` | `curl -v http://localhost:8080/` → `Empty reply from server` |
| `local-06-escucha-loopback.png` | `ss -tln \| grep 8080` o `netstat -ano \| findstr :8080` solo en 127.0.0.1 |
| `reverse-01-tunel-y-servidor.png` | Terminal 1 con `./lab7/tuneles/reverse.sh` y el log `"GET / HTTP/1.1" 200` |
| `reverse-02-curl-bastion.png` | `ssh bastion 'curl -s localhost:9090'` con el HTML de la laptop |
| `reverse-03-escucha-loopback.png` | `ssh bastion 'ss -tln \| grep 9090'` solo en 127.0.0.1 y [::1] |
| `reverse-04-it01-bloqueado.png` | Prueba desde it-01 al 9090 del Bastion → `bloqueado` |
| `tuneles-cerrados.png` | Las dos verificaciones de "sin túneles" después de Ctrl+C |
