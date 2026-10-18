# Security Groups. Las reglas van como recursos separados
# (aws_vpc_security_group_*_rule) para poder sumarlas desde otros archivos
# sin que Terraform borre las que ya existen.

# ---------------------------------------------------------------------------
# Bastion: SSH solo desde la IP del administrador
# ---------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion-sg"
  description = "SSH desde la IP del administrador"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-bastion-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_admin" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH administrador"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Ventas: SSH desde Bastion, ICMP solo entre instancias de Ventas
# ---------------------------------------------------------------------------
resource "aws_security_group" "sales" {
  name        = "${local.name}-sales-sg"
  description = "Instancias de Ventas"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-sales-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "sales_ssh_bastion" {
  security_group_id            = aws_security_group.sales.id
  description                  = "SSH desde Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "sales_icmp_self" {
  security_group_id            = aws_security_group.sales.id
  description                  = "ICMP entre instancias de Ventas"
  ip_protocol                  = "icmp"
  from_port                    = -1
  to_port                      = -1
  referenced_security_group_id = aws_security_group.sales.id
}

resource "aws_vpc_security_group_egress_rule" "sales_all" {
  security_group_id = aws_security_group.sales.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# TI: SSH desde Bastion
# ---------------------------------------------------------------------------
resource "aws_security_group" "it" {
  name        = "${local.name}-it-sg"
  description = "Instancias de TI"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-it-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "it_ssh_bastion" {
  security_group_id            = aws_security_group.it.id
  description                  = "SSH desde Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "it_all" {
  security_group_id = aws_security_group.it.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Data Center: SSH desde Bastion y TI, ICMP solo desde TI
# Ventas y Visitas no tienen ninguna regla, por lo que quedan bloqueadas
# ---------------------------------------------------------------------------
resource "aws_security_group" "datacenter" {
  name        = "${local.name}-datacenter-sg"
  description = "Servidores del Data Center"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-datacenter-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "datacenter_ssh_bastion" {
  security_group_id            = aws_security_group.datacenter.id
  description                  = "SSH desde Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "datacenter_ssh_it" {
  security_group_id            = aws_security_group.datacenter.id
  description                  = "SSH desde TI"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.it.id
}

resource "aws_vpc_security_group_ingress_rule" "datacenter_icmp_it" {
  security_group_id            = aws_security_group.datacenter.id
  description                  = "ICMP desde TI"
  ip_protocol                  = "icmp"
  from_port                    = -1
  to_port                      = -1
  referenced_security_group_id = aws_security_group.it.id
}

resource "aws_vpc_security_group_egress_rule" "datacenter_all" {
  security_group_id = aws_security_group.datacenter.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Visitas: sin reglas de entrada
# ---------------------------------------------------------------------------
resource "aws_security_group" "guest" {
  name        = "${local.name}-guest-sg"
  description = "Red de visitas, sin entrada"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-guest-sg" }
}

resource "aws_vpc_security_group_egress_rule" "guest_all" {
  security_group_id = aws_security_group.guest.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# RRHH: SSH desde Bastion, ICMP solo entre instancias de RRHH
# ---------------------------------------------------------------------------
resource "aws_security_group" "hr" {
  name        = "${local.name}-hr-sg"
  description = "Instancias de Recursos Humanos"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-hr-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "hr_ssh_bastion" {
  security_group_id            = aws_security_group.hr.id
  description                  = "SSH desde Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "hr_icmp_self" {
  security_group_id            = aws_security_group.hr.id
  description                  = "ICMP entre instancias de RRHH"
  ip_protocol                  = "icmp"
  from_port                    = -1
  to_port                      = -1
  referenced_security_group_id = aws_security_group.hr.id
}

resource "aws_vpc_security_group_egress_rule" "hr_all" {
  security_group_id = aws_security_group.hr.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Intranet (servidor web del Data Center): HTTP desde todas las subredes
# menos Visitas. No tiene IP pública, así que desde Internet no se llega.
# ---------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "Servidor web de la intranet"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-web-sg" }
}

# TI tiene acceso total por la regla "from_it"
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  for_each = {
    ventas          = aws_security_group.sales.id
    rrhh            = aws_security_group.hr.id
    datacenter      = aws_security_group.web.id
    datacenter_ldap = aws_security_group.ldap.id
    bastion         = aws_security_group.bastion.id
    firewall        = aws_security_group.fw.id
  }

  security_group_id            = aws_security_group.web.id
  description                  = "HTTP desde ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh_bastion" {
  security_group_id            = aws_security_group.web.id
  description                  = "SSH desde Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# TI llega a todas las subredes; ninguna subred llega a TI (SG-TI solo acepta
# SSH desde el Bastion, que es el acceso de administración)
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "from_it" {
  for_each = {
    bastion    = aws_security_group.bastion.id
    sales      = aws_security_group.sales.id
    datacenter = aws_security_group.datacenter.id
    guest      = aws_security_group.guest.id
    hr         = aws_security_group.hr.id
    web        = aws_security_group.web.id
  }

  security_group_id            = each.value
  description                  = "TI llega a todas las subredes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.it.id
}
