# Servidor LDAP (Fase 2) en el Data Center: OpenLDAP con LDAPS. Aquí se
# administran los usuarios y grupos de Ventas, RRHH y TI.

locals {
  ldap_uri     = "ldaps://${local.ldap_ip}"
  ldap_base_dn = "dc=barrilete,dc=dev"

  ldap_groups = {
    "ventas-users" = 10001
    "rrhh-users"   = 10002
    "ti-admins"    = 10003
  }

  # Usuarios de demostración, uno por grupo
  ldap_users = {
    vendedor1 = { uid = 20001, group = "ventas-users", cn = "Vendedor Uno", sn = "Uno" }
    rrhh1     = { uid = 20002, group = "rrhh-users", cn = "Recursos Humanos Uno", sn = "Uno" }
    ti1       = { uid = 20003, group = "ti-admins", cn = "TI Uno", sn = "Uno" }
  }
}

resource "random_password" "ldap_admin" {
  length  = 20
  special = false
}

resource "random_password" "ldap_user" {
  for_each = local.ldap_users
  length   = 14
  special  = false
}

resource "aws_security_group" "ldap" {
  name        = "${local.name}-ldap-sg"
  description = "Servidor LDAP del Data Center"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-ldap-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ldap_ldaps_sales" {
  security_group_id            = aws_security_group.ldap.id
  description                  = "LDAPS desde Ventas"
  ip_protocol                  = "tcp"
  from_port                    = 636
  to_port                      = 636
  referenced_security_group_id = aws_security_group.sales.id
}

resource "aws_vpc_security_group_ingress_rule" "ldap_ssh_bastion" {
  security_group_id            = aws_security_group.ldap.id
  description                  = "SSH desde el Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "ldap_from_it" {
  security_group_id            = aws_security_group.ldap.id
  description                  = "TI llega a todas las subredes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.it.id
}

resource "aws_vpc_security_group_egress_rule" "ldap_all" {
  security_group_id = aws_security_group.ldap.id
  description       = "Salida (paquetes por el firewall)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "ldap" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.datacenter.id
  private_ip                  = local.ldap_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ldap.id]
  key_name                    = var.key_name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/../scripts/ldap.sh.tftpl", {
    ca_cert        = tls_self_signed_cert.ca.cert_pem
    server_cert    = tls_locally_signed_cert.ldap.cert_pem
    server_key     = tls_private_key.ldap.private_key_pem
    base_dn        = local.ldap_base_dn
    admin_password = random_password.ldap_admin.result
    groups         = local.ldap_groups
    users          = local.ldap_users
    passwords      = { for k, p in random_password.ldap_user : k => p.result }
  })

  # Instala paquetes al arrancar: necesita la salida a Internet por el firewall
  depends_on = [aws_route_table.private]

  tags = { Name = "${local.name}-dc-ldap" }
}
