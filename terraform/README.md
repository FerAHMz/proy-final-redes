# barrilete.dev – Red en AWS (Fase 1)

Infraestructura de red de la Fase 1 del proyecto final de CC3067 Redes, definida con Terraform sobre Amazon Web Services.

## Arquitectura

| Segmento | CIDR | Tipo | Instancias |
|---|---|---|---|
| Ventas | `192.168.10.0/26` | privada | `barrilete-sales-01` (.10), `barrilete-sales-02` (.11) |
| Visitas | `192.168.10.64/26` | privada | `barrilete-guest-01` (.74, opcional) |
| TI | `192.168.10.128/27` | privada | `barrilete-it-01` (.138) |
| Data Center | `192.168.10.160/28` | privada | `barrilete-dc-01..05` (.164 en adelante) |
| Administración | `192.168.10.176/28` | pública | `barrilete-bastion` (.180) |
| Reserva | `192.168.10.192/26` | — | sin uso, crecimiento futuro |

- **Internet Gateway** `barrilete-igw`: solo la tabla `barrilete-public-rt` (asociada a Administración) tiene la ruta `0.0.0.0/0 → IGW`.
- **Tabla privada** `barrilete-private-rt`: solo la ruta `local`. Ventas, Visitas, TI y Data Center no tienen salida a Internet ni IP pública. No se usa NAT Gateway.
- **Bastion**: única instancia con IP pública. Desde ahí se administra el resto por SSH.

### Security Groups

| SG | Entrada |
|---|---|
| `barrilete-bastion-sg` | TCP 22 desde `admin_cidr` |
| `barrilete-sales-sg` | TCP 22 desde Bastion, ICMP desde el mismo SG |
| `barrilete-it-sg` | TCP 22 desde Bastion |
| `barrilete-datacenter-sg` | TCP 22 desde Bastion y TI, ICMP desde TI |
| `barrilete-guest-sg` | ninguna |

Todos permiten tráfico saliente. Como los Security Groups solo permiten (todo lo demás se niega), Visitas y Ventas no pueden llegar al Data Center porque no existe ninguna regla que lo habilite.

### Decisiones no definidas en el SPEC

- IPs privadas fijas en cada instancia para que las pruebas y capturas sean reproducibles.
- No se crea NACL personalizada; el aislamiento se hace con Security Groups.
- Por defecto se despliega 1 servidor de Data Center (`datacenter_instance_count`), aunque el diseño contempla 5.

## Requisitos

- Terraform ≥ 1.6
- AWS CLI (opcional, para `aws configure`)
- Credenciales de un usuario IAM en `~/.aws/credentials`. No se guardan credenciales en Terraform.
- Un Key Pair existente en EC2 (EC2 → Key Pairs → Create key pair, formato `.pem`).
- La IP pública del administrador:
  ```bash
  curl https://checkip.amazonaws.com
  ```

## Despliegue

```bash
cp terraform.tfvars.example terraform.tfvars   # editar admin_cidr y key_name
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Acceso SSH

Las instancias privadas se alcanzan saltando por el Bastion con **ProxyJump**. Se agrega la llave al `ssh-agent` para que sirva en ambos saltos sin copiarla al Bastion:

```bash
chmod 400 barrilete-key.pem
ssh-add barrilete-key.pem
ssh -J ec2-user@<BASTION_PUBLIC_IP> ec2-user@<SALES_01_PRIVATE_IP>
```

El comando exacto aparece en el output `ssh_sales_01_command`.

## Pruebas

| Prueba | Origen | Destino | Comando | Esperado |
|---|---|---|---|---|
| A | Sales-01 | Sales-02 | `ping -c 4 192.168.10.11` | SUCCESS |
| B | Bastion | Sales-01 | `ssh ec2-user@192.168.10.10` | SUCCESS |
| C | IT-01 | DC-01 | `ssh ec2-user@192.168.10.164` (con `ssh -A` hacia IT-01) | SUCCESS |
| D | Guest-01 | DC-01 | `ping -c 4 192.168.10.164` | BLOCKED |
| E | IT-01 | Sales-01 | `ping -c 4 192.168.10.10` | BLOCKED |

La prueba D requiere `create_guest_instance = true`. Para entrar a Guest-01 desde el Bastion habría que permitir SSH desde el Bastion en `barrilete-guest-sg`; la prueba E demuestra el mismo aislamiento sin abrir nada.

## Destruir

⚠️ Al terminar las pruebas ejecutar:

```bash
terraform destroy
```

Las EC2 cobran mientras estén encendidas y la IP pública del Bastion también tiene costo. Volver a crear todo con `terraform apply` toma pocos minutos.
