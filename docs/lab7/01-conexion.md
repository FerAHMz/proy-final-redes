# Lab 7 – 3.1 Instancias de TI y conexión con llaves

El lab pide dos Linux en la subred de TI y entrar a ellas desde nuestras laptops con llave SSH, no desde la consola de AWS. it-01 ya existía, así que solo sumamos it-02.

## Qué cambió en Terraform

| Archivo | Cambio |
|---|---|
| `terraform/ec2.tf` | `aws_instance.it_02` en la subred de TI con IP fija `192.168.10.139` (`cidrhost(var.it_subnet_cidr, 11)`), SG `it` y sin IP pública |
| `terraform/security-groups.tf` | `it_self`: TCP 22 y TCP 4444 solo entre instancias del SG de TI |
| `terraform/outputs.tf` | output `it_02_private_ip` |

Algunas decisiones:

- it-02 va como recurso aparte. Si convertíamos `aws_instance.it` a `for_each`, Terraform destruía y recreaba it-01.
- La regla nueva apunta al mismo SG de TI. Así it-01 e it-02 se hablan por SSH (para el multi-hop) y por el 4444 (para ncat), pero Ventas, RRHH y Visitas siguen sin poder entrar a TI.
- No abrimos nada más. El resto de puertos sigue cerrado y el SSH desde fuera sigue entrando solo por el Bastion.

Para aplicarlo:

```bash
cd terraform
terraform plan     # esperado: Plan: 3 to add, 0 to change, 0 to destroy
terraform apply
terraform output it_02_private_ip   # "192.168.10.139"
```

Los 3 recursos nuevos son `aws_instance.it_02`, `it_self["ssh"]` e `it_self["ncat"]`. Si el plan dice que va a destruir algo, paren y revisen.

## Permisos de la llave privada

SSH se niega a usar una llave que otros usuarios puedan leer (sale `UNPROTECTED PRIVATE KEY FILE!`). Por eso hay que dejarla en solo lectura para el dueño.

Linux / macOS:

```bash
chmod 400 ~/.ssh/barrillete-key.pem
ls -l ~/.ssh/barrillete-key.pem
# -r-------- 1 usuario usuario 1678 ... barrillete-key.pem
```

Windows (PowerShell):

```powershell
$llave = "$env:USERPROFILE\.ssh\barrillete-key.pem"
icacls $llave /inheritance:r
icacls $llave /grant:r "$($env:USERNAME):(R)"
icacls $llave
# C:\Users\<usuario>\.ssh\barrillete-key.pem <EQUIPO>\<usuario>:(R)
```

`/inheritance:r` quita los permisos heredados de la carpeta (Users, Administrators, etc.) y `/grant:r` deja solo lectura para tu usuario.

## Config de SSH

Copiá [`lab7/ssh_config.example`](../../lab7/ssh_config.example) a `~/.ssh/config` y poné la IP pública del Bastion:

```bash
terraform -chdir=terraform output -raw bastion_public_ip
```

Con `ProxyJump bastion`, la conexión a it-01 o it-02 pasa por el Bastion, pero la llave nunca sale de la laptop. Por eso no hace falta copiar el `.pem` a ninguna instancia.

## Conexión

```bash
ssh bastion 'hostname'
ssh it-01 'hostname; hostname -I'
ssh it-02 'hostname; hostname -I'
```

Salida esperada:

```
ip-192-168-10-180.ec2.internal
ip-192-168-10-138.ec2.internal
192.168.10.138
ip-192-168-10-139.ec2.internal
192.168.10.139
```

Sin el archivo de config, lo mismo sería:

```bash
ssh -i ~/.ssh/barrillete-key.pem -J ec2-user@<BASTION_IP> ec2-user@192.168.10.139
```

Para comprobar que entramos con llave y no con contraseña:

```bash
ssh -v it-02 exit 2>&1 | grep -E "Authenticated|Offering public key"
# debug1: Offering public key: .../barrillete-key.pem RSA ...
# Authenticated to 192.168.10.139 (via proxy) using "publickey".
```

## Verificar que no rompimos el hardening

Desde la raíz del repo:

```bash
./scripts/smoke-tests.sh
```

Tienen que pasar las 21 pruebas, en especial estas:

- 11 "Ventas NO llega a TI por SSH" → `timed out`
- 12 "RRHH NO llega a TI por ping" → `100% packet loss`

Además, para ver que Ventas tampoco llega al 4444 de TI:

```bash
ssh -J bastion ec2-user@192.168.10.10 'timeout 5 bash -c "</dev/tcp/192.168.10.139/4444" && echo abierto || echo bloqueado'
# bloqueado
```

## Capturas (en `evidencias/lab7/`)

| Archivo | Qué se ve |
|---|---|
| `01-terraform-apply-it02.png` | `terraform apply` con los 3 recursos nuevos y el output `it_02_private_ip` |
| `02-consola-instancias-ti.png` | Consola EC2 con `barrilete-it-01` y `barrilete-it-02`, sin IP pública |
| `03-permisos-llave.png` | `chmod 400` + `ls -l`, o `icacls` en Windows |
| `04-ssh-it01.png` | `ssh it-01 'hostname; hostname -I'` desde la laptop |
| `05-ssh-it02.png` | `ssh it-02 'hostname; hostname -I'` desde la laptop |
| `06-ssh-publickey.png` | `ssh -v it-02 exit` con `Authenticated ... using "publickey"` |
| `07-smoke-tests.png` | `./scripts/smoke-tests.sh` con todas correctas |
| `08-ventas-no-llega-ti-4444.png` | Prueba del 4444 desde Ventas → `bloqueado` |
