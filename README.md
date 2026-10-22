# Barrilete Ventures – Red en AWS

Proyecto Final de CC3067 Redes (UVG): diseño, segmentación e implementación de la red de la startup **Barrilete Ventures** (`barrilete.dev`) en Amazon Web Services.

- **Fase 1:** VPC segmentada con CIDR/VLSM, Bastion y pruebas de conectividad.
- **Fase 2:** firewall con NAT, ACL, DNS privado, intranet web de RRHH y autenticación SSH con LDAP.

## Integrantes

- Ana Laura Tschen – 221645
- Fernando Rueda – 23748
- Luis Felipe Aguilar Portillo – 23195
- Fernando Hernández – 23645
- Esteban Cárcamo – 23016

## Segmentación (CIDR/VLSM)

Red base de la VPC: `192.168.10.0/24`

| Segmento | Red | Máscara | IP utilizables en AWS | Instancias |
|---|---|---|---:|---|
| Ventas | `192.168.10.0/26` | 255.255.255.192 | 59 | sales-01 `.10`, sales-02 `.11` |
| Visitas | `192.168.10.64/26` | 255.255.255.192 | 59 | guest-01 `.74` |
| TI | `192.168.10.128/27` | 255.255.255.224 | 27 | it-01 `.138` |
| Data Center | `192.168.10.160/28` | 255.255.255.240 | 11 | dc-01 (web) `.164`, dc-ldap `.170` |
| Administración | `192.168.10.176/28` | 255.255.255.240 | 11 | bastion `.180`, fw `.181` |
| RRHH (Fase 2) | `192.168.10.192/28` | 255.255.255.240 | 11 | hr-01 `.196` |
| Reserva | `192.168.10.208` – `.255` | — | — | crecimiento futuro |

AWS reserva 5 direcciones por subred y no permite prefijos menores a /28. Los cálculos completos están en `docs/Grupo 1 - Segmentacion_red_Barrilete.xlsx`.

## Servicios de la Fase 2

| Servicio | Dónde | Cómo |
|---|---|---|
| Firewall + NAT | `barrilete-fw` (Administración) | nftables: solo deja salir 80, 443 e ICMP hacia Internet; `masquerade` para las subredes privadas |
| ACL | Subred de Visitas | NACL: Visitas sale a Internet pero no llega a ninguna subred; solo TI puede entrar |
| DNS | Route 53, zona privada `barrilete.dev` | `rrhh.barrilete.dev` → `.164`, `ldap.barrilete.dev` → `.170`; solo existe dentro de la VPC |
| HTTP | `dc-01` (Data Center) | Nginx: la intranet *Barrilete People* solo responde por nombre; por IP cierra la conexión |
| LDAP | `dc-ldap` (Data Center) | OpenLDAP con LDAPS (636) y CA propia generada por Terraform |
| SSH con LDAP | Ventas y RRHH | SSSD: solo entran los grupos `ventas-users` / `rrhh-users` (y `ti-admins`) |

**Reglas de acceso:** TI llega a todas las subredes y ninguna llega a TI; la intranet es accesible desde todas las subredes menos Visitas y no tiene IP pública; el SSH a la red solo entra por el Bastion desde la IP del administrador.

## Estructura del repositorio

```
├── terraform/   Infraestructura como código (red, firewall, Security Groups, NACL, DNS, LDAP, EC2)
├── scripts/     Scripts de arranque de las instancias (firewall, LDAP, clientes SSSD, web)
├── web/         Página estática de la intranet de RRHH
├── capturas/    Evidencias de la Fase 1
└── docs/        Propuesta técnica, diagrama y cálculos de segmentación
```

## Despliegue

Requisitos: Terraform ≥ 1.6, credenciales de AWS y el Key Pair `barrillete-key` cargado con `ssh-add`.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # admin_cidr = tu IP pública /32
terraform init
terraform apply                                 # ~3 min + ~3 min de configuración automática
```

Todo se configura solo al arrancar (`user_data`); no hay pasos manuales. Al terminar:

```bash
terraform destroy
```

## Acceso y pruebas básicas

```bash
B=$(terraform output -raw bastion_public_ip)
terraform output -json ldap_user_passwords        # contraseñas de vendedor1, rrhh1 y ti1

ssh -J ec2-user@$B vendedor1@192.168.10.10        # entra (Ventas)
ssh -J ec2-user@$B rrhh1@192.168.10.10            # rechazado (no es de Ventas)
ssh -J ec2-user@$B rrhh1@192.168.10.196           # entra (RRHH)

ssh -J ec2-user@$B ec2-user@192.168.10.10 'curl -s http://rrhh.barrilete.dev'   # intranet por nombre
```

A Visitas solo se entra pasando por TI: `ssh -J ec2-user@$B,ec2-user@192.168.10.138 ec2-user@192.168.10.74`.
