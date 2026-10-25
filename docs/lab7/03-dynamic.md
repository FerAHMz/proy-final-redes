# Lab 7 – 3.2 Túnel dinámico (-D) / proxy SOCKS

Con `-L` y `-R` (ver [02-local-reverse.md](02-local-reverse.md)) el destino queda fijo en el comando: un puerto, un host. Con `-D` no. ssh levanta un **servidor SOCKS** en la laptop y cada aplicación le dice en el momento a qué host y puerto quiere ir. El Bastion abre esa conexión desde adentro de la VPC.

En corto: `-L` es un tubo hacia un solo lugar y `-D` es una puerta a toda la VPC (o a Internet saliendo por el Bastion).

Usa el host `bastion` de [`lab7/ssh_config.example`](../../lab7/ssh_config.example) (ver [01-conexion.md](01-conexion.md)).

## Cómo funciona

```
 Laptop                           Bastion (.180)                  VPC / Internet
┌──────────────────────────┐    ┌──────────────────────────┐    ┌──────────────────┐
│ Firefox / curl           │    │ sshd                     │    │ dc-01 (.164)     │
│ "quiero ir a             │    │  1. resuelve el nombre   │ 80 │ Nginx            │
│  rrhh.barrilete.dev:80"  │    │     con el DNS privado   ├───►│ rrhh.barrilete.  │
│   │                      │SSH │     de la VPC (.2)       │    │ dev              │
│   ▼                      │:22 │  2. abre la conexión TCP │    └──────────────────┘
│ 127.0.0.1:1080 ══════════╪════╪═►   al destino pedido    │    ┌──────────────────┐
│ (servidor SOCKS, ssh -D) │    │                          ├───►│ Internet (sale   │
└──────────────────────────┘    └──────────────────────────┘443 │ con la IP del    │
                                                                │ Bastion, por IGW)│
                                                                └──────────────────┘
```

1. `ssh -D 1080 bastion` hace que la laptop escuche en `127.0.0.1:1080`, pero ahí no hay un destino fijo: hay un servidor SOCKS.
2. La aplicación (Firefox, curl) se conecta al 1080 y hace el saludo SOCKS5: "quiero ir a `rrhh.barrilete.dev`, puerto 80" (comando `CONNECT` de la RFC 1928).
3. ssh manda ese pedido por el canal cifrado y el **Bastion** abre la conexión TCP al destino. Si el destino viene como nombre, el que lo resuelve es el Bastion.
4. Desde ahí, ssh solo pasa bytes de un lado al otro. No lee el HTTP ni le cambia nada.
5. Cada pestaña, cada imagen y cada host nuevo es otro `CONNECT` sobre la misma sesión SSH. Por eso con un solo túnel se navega por varios servicios.

No tocamos Terraform: el SG `web` ya deja entrar HTTP desde el SG del Bastion y el Bastion tiene salida a Internet.

## socks5 vs socks5h: quién resuelve el nombre

Esta es la parte clave del ejercicio. `barrilete.dev` vive en una zona **privada** de Route 53 asociada a la VPC. La laptop no la conoce, pero el Bastion sí (le pregunta al resolver de la VPC, en `192.168.10.2`).

SOCKS5 deja mandar el destino de dos formas (campo `ATYP` de la RFC 1928):

| Modo | En curl | Qué manda la laptop | Quién resuelve | Resultado con `rrhh.barrilete.dev` |
|---|---|---|---|---|
| socks5 | `--socks5` o `socks5://` | una IP (`ATYP = 0x01`) | la laptop | falla: la laptop no encuentra el nombre |
| socks5h | `--socks5-hostname` o `socks5h://` | el nombre tal cual (`ATYP = 0x03`) | el Bastion | funciona: el Bastion lo resuelve a `192.168.10.164` |

La `h` es de *hostname*: el nombre viaja dentro del túnel y se resuelve del otro lado. Eso trae dos ventajas:

- **Llegamos a nombres privados.** Sin tocar el archivo hosts (a diferencia del túnel local) y sin configurar DNS en la laptop.
- **No hay fuga de DNS.** La red de la casa o la U no ve qué nombres consultamos, porque esa consulta nunca sale de la laptop.

Además, como en la URL va el nombre, el navegador manda `Host: rrhh.barrilete.dev` y Nginx responde. Con `-L` teníamos que mentirle al archivo hosts para lograr eso.

En Firefox, lo mismo es la casilla **"Proxy DNS when using SOCKS v5"** (en `about:config` es `network.proxy.socks_remote_dns = true`). Si no se marca, Firefox resuelve en la laptop y la intranet no carga.

## Comandos

### Terminal 1: abrir el proxy

```bash
./lab7/tuneles/dynamic.sh
# equivale a: ssh -N -o ExitOnForwardFailure=yes -D 1080 bastion
```

`-N` evita abrir una shell en el Bastion. Sin `-N` (`ssh -D 1080 bastion`) también funciona y además te deja una sesión abierta.

Antes de probar, quitá la línea `127.0.0.1 rrhh.barrilete.dev` del archivo hosts si te quedó del túnel local. Con SOCKS no hace falta.

### Terminal 2: pruebas con curl

En Windows PowerShell usá `curl.exe`, porque `curl` a secas es un alias de `Invoke-WebRequest`.

```bash
# 1. Con socks5h: el nombre se resuelve en el Bastion y la intranet responde
curl -s --socks5-hostname localhost:1080 http://rrhh.barrilete.dev | grep -E "<title>|<h1>"
```

```
  <title>Barrilete People</title>
      <h1>Bienvenido a la intranet de Recursos Humanos</h1>
```

```bash
# 2. Con socks5 (sin h): curl intenta resolver en la laptop y no puede
curl --socks5 localhost:1080 http://rrhh.barrilete.dev
```

```
curl: (6) Could not resolve host: rrhh.barrilete.dev
```

Si te sale otra cosa (por ejemplo `Can't complete SOCKS5 connection to 127.0.0.1`), es que la línea del archivo hosts sigue ahí: curl resolvió a `127.0.0.1` y le pidió al Bastion conectarse a su propio puerto 80.

```bash
# 3. Para comparar: quién resuelve qué
nslookup rrhh.barrilete.dev                      # laptop: no lo encuentra
ssh bastion 'getent hosts rrhh.barrilete.dev'    # Bastion: 192.168.10.164 rrhh.barrilete.dev
```

```bash
# 4. Salida a Internet: con el proxy salimos con la IP pública del Bastion
curl -s https://checkip.amazonaws.com                                   # IP de tu casa o la U
curl -s --socks5-hostname localhost:1080 https://checkip.amazonaws.com  # IP pública del Bastion
terraform -chdir=terraform output -raw bastion_public_ip                # debe coincidir con la anterior
```

```bash
# 5. El proxy escucha solo en loopback
ss -tln | grep 1080              # Linux/macOS: 127.0.0.1:1080 y [::1]:1080
netstat -ano | findstr :1080     # Windows: 127.0.0.1:1080 LISTENING
```

Truco: si corrés el túnel con `ssh -v -N -D 1080 bastion`, cada petición deja en la terminal 1 una línea como `debug1: Connection to port 1080 forwarding to socks port 0 requested.` Sirve para ver que el tráfico sí pasa por ahí.

### Firefox

1. Ajustes → General → Configuración de red → **Configuración…**
2. **Configuración manual del proxy**:
   - Proxy HTTP: vacío
   - Servidor SOCKS: `127.0.0.1`, puerto `1080`
   - Marcar **SOCKS v5**
3. Marcar **Proxy DNS when using SOCKS v5**.
4. Aceptar y abrir `http://rrhh.barrilete.dev` (sin `:8080`, ahora vamos directo al 80).

Debe cargar Barrilete People. Si Firefox insiste en `https://`, desactivá el modo "Solo HTTPS" para la prueba. Si tenés activado DNS sobre HTTPS y no carga, apagalo también mientras probás.

Conviene usar Firefox porque tiene su propia config de proxy. Chrome y Edge usan la del sistema y no tienen la casilla del DNS remoto en la interfaz.

### Hardening

- El servidor SOCKS escucha solo en `127.0.0.1`. ssh no lo abre a la red local salvo que se ponga `GatewayPorts yes` en el cliente o un `bind_address` como `0.0.0.0:1080`, y no hacemos ninguna de las dos.
- No abrimos ningún puerto nuevo en los SG ni en el firewall. Todo viaja dentro del 22 del Bastion, que sigue limitado a `admin_cidr`.
- Ojo: mientras el proxy está abierto, cualquier programa de la laptop que lo use llega a toda la VPC con los permisos del Bastion. Por eso se cierra apenas terminan las pruebas.

## Cerrar el túnel

- **Ctrl+C** en la terminal 1.
- Si se quedó colgado: Enter y luego `~.` (secuencia de escape de ssh).
- Si se abrió en segundo plano con `-f`:

```bash
pkill -f "ssh .*-D 1080"                         # Linux/macOS
```

```powershell
Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" | Where-Object CommandLine -match "-D 1080" | ForEach-Object { Stop-Process -Id $_.ProcessId }
```

Verificar que no quedó nada (lo pide el checklist final):

```bash
ss -tln | grep :1080 || echo "sin proxy SOCKS en la laptop"
netstat -ano | findstr :1080                     # Windows: no debe salir nada
```

En Firefox, volver a **Sin proxy**. Si lo dejás en manual con el túnel cerrado, ninguna página carga.

## Casos de uso

### Académico

En un curso de Data Science o Big Data, el catedrático da un clúster con Hadoop/Spark (por ejemplo Amazon EMR) en una subred privada. Las interfaces web (YARN, Spark History Server, los logs de cada worker) están en varios nodos y puertos distintos, y los links entre ellas usan nombres internos del clúster. El estudiante abre `ssh -D 1080 hadoop@nodo-principal`, configura Firefox con SOCKS5 y DNS remoto, y navega todas las interfaces como si estuviera adentro.

*Justificación:* con `-L` haría falta un túnel por cada nodo y puerto, y los links internos se romperían porque apuntan a nombres que la laptop no resuelve. Con `-D` alcanza un solo túnel y el DNS se resuelve en el clúster. No es inventado: AWS documenta justo este método (túnel dinámico + proxy en el navegador) para ver las interfaces web de EMR.

### Comercial

Un equipo de soporte o de DevOps administra varios paneles internos en la VPC de un cliente: Grafana, Jenkins, la consola de un router, un NAS, la intranet. Ninguno tiene IP pública. En vez de montar una VPN o abrir un túnel `-L` por panel, el técnico hace `ssh -D 1080 bastion` y entra a todos por nombre interno desde el navegador. El mismo truco sirve para trabajar desde el Wi-Fi de un aeropuerto o un café: todo el navegador sale cifrado hasta el Bastion de la empresa.

*Justificación:* los paneles siguen sin exponerse a Internet, el acceso pasa por un solo punto controlado (llaves, logs y `admin_cidr` del Bastion), no hay que instalar ni mantener un servidor VPN, y quitarle el acceso a alguien es borrar su llave. Además, con socks5h los nombres internos no se filtran al DNS de la red pública donde esté el técnico.

## Capturas (en `evidencias/lab7/`)

| Archivo | Qué se ve |
|---|---|
| `dynamic-01-tunel-abierto.png` | Terminal 1 con `./lab7/tuneles/dynamic.sh` corriendo |
| `dynamic-02-curl-socks5h.png` | `curl -s --socks5-hostname localhost:1080 http://rrhh.barrilete.dev \| grep -E "<title>\|<h1>"` con Barrilete People |
| `dynamic-03-curl-socks5-falla.png` | `curl --socks5 localhost:1080 http://rrhh.barrilete.dev` → `Could not resolve host` |
| `dynamic-04-dns-laptop-vs-bastion.png` | `nslookup` en la laptop sin respuesta y `ssh bastion 'getent hosts rrhh.barrilete.dev'` con `192.168.10.164` |
| `dynamic-05-ip-salida.png` | `checkip.amazonaws.com` sin proxy y con proxy, más el output `bastion_public_ip` |
| `dynamic-06-firefox-config.png` | Ventana de configuración de red de Firefox con SOCKS v5 y "Proxy DNS when using SOCKS v5" marcado |
| `dynamic-07-firefox-rrhh.png` | Firefox en `http://rrhh.barrilete.dev` con la intranet cargada |
| `dynamic-08-escucha-loopback.png` | `ss -tln \| grep 1080` o `netstat -ano \| findstr :1080` solo en 127.0.0.1 |
| `dynamic-09-tunel-cerrado.png` | Verificación de "sin proxy SOCKS" después de Ctrl+C |
