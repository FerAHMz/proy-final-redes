variable "aws_region" {
  description = "Región de AWS donde se despliega la red"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado en tags"
  type        = string
  default     = "barrilete-network"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "Bloque privado de la VPC"
  type        = string
  default     = "192.168.10.0/24"
}

variable "sales_subnet_cidr" {
  description = "Subred de Ventas (25 colaboradores)"
  type        = string
  default     = "192.168.10.0/26"
}

variable "guest_subnet_cidr" {
  description = "Subred de Visitas"
  type        = string
  default     = "192.168.10.64/26"
}

variable "it_subnet_cidr" {
  description = "Subred de TI (15 colaboradores)"
  type        = string
  default     = "192.168.10.128/27"
}

variable "datacenter_subnet_cidr" {
  description = "Subred del Data Center (5 servidores)"
  type        = string
  default     = "192.168.10.160/28"
}

variable "management_subnet_cidr" {
  description = "Subred de Administración (Bastion)"
  type        = string
  default     = "192.168.10.176/28"
}

variable "admin_cidr" {
  description = "IP pública del administrador en notación CIDR, se recomienda /32"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr debe estar en notación CIDR, por ejemplo 203.0.113.10/32."
  }
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (Free Tier: t3.micro o t2.micro)"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nombre de un Key Pair existente en AWS para acceder a las instancias"
  type        = string
}

variable "datacenter_instance_count" {
  description = "Número de servidores del Data Center a desplegar (el diseño contempla 5)"
  type        = number
  default     = 1

  validation {
    condition     = var.datacenter_instance_count >= 0 && var.datacenter_instance_count <= 5
    error_message = "datacenter_instance_count debe estar entre 0 y 5."
  }
}

variable "create_guest_instance" {
  description = "Crear una instancia de prueba en la red de Visitas"
  type        = bool
  default     = false
}
