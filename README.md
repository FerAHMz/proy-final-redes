# Barrilete Ventures – Red en AWS

Proyecto Final de CC3067 Redes (UVG), Fase 1: diseño, segmentación e implementación de la red de la startup **Barrilete Ventures** (`barrilete.dev`) en Amazon Web Services.

## Integrantes

- Ana Laura Tschen – 221645
- Fernando Rueda – 23748
- Luis Felipe Aguilar Portillo – 23195
- Fernando Hernández – 23645
- Esteban Cárcamo – 23016

## Segmentación (CIDR/VLSM)

Red base de la VPC: `192.168.10.0/24`

| Segmento | Red | Máscara | IP utilizables en AWS | Requerimiento |
|---|---|---|---:|---|
| Ventas | `192.168.10.0/26` | 255.255.255.192 | 59 | 25 personas |
| Visitas | `192.168.10.64/26` | 255.255.255.192 | 59 | 50 hosts |
| TI | `192.168.10.128/27` | 255.255.255.224 | 27 | 15 personas |
| Data Center | `192.168.10.160/28` | 255.255.255.240 | 11 | 5 servidores |
| Administración | `192.168.10.176/28` | 255.255.255.240 | 11 | Bastion |
| Reserva | `192.168.10.192/26` | 255.255.255.192 | — | Crecimiento futuro |

AWS reserva 5 direcciones por subred y no permite prefijos menores a /28, por eso el Data Center usa /28.

## Estructura del repositorio

```
├── terraform/      Infraestructura como código (VPC, subredes, rutas, Security Groups, EC2)
├── capturas/       Evidencias de la consola de AWS y de las pruebas de conectividad
└── docs/           Propuesta técnica (PDF) y cálculos de segmentación (Excel)
```

## Despliegue

Las instrucciones para desplegar, probar y destruir la infraestructura están en [`terraform/README.md`](terraform/README.md).

Resumen:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # admin_cidr y key_name
terraform init
terraform apply
# ... pruebas ...
terraform destroy
```

## Pruebas de conectividad

| # | Origen → Destino | Resultado |
|---|---|---|
| 1 | Sales-01 → Sales-02 (ping, misma subred) | ✅ Responde |
| 2 | IT-01 → Sales-01 (ping) | 🚫 Bloqueado por Security Group |
| 3 | IT-01 → DC-01 (ping) | ✅ Responde |
| 4 | IT-01 → DC-01 (SSH) | ✅ Acceso administrativo |
