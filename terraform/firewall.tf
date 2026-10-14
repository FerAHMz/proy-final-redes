# Firewall con NAT (Fase 2): reenvía la salida a Internet de las subredes
# privadas y filtra con nftables. El tráfico interno de la VPC no pasa por
# aquí porque la ruta local siempre gana.

resource "aws_security_group" "fw" {
  name        = "${local.name}-fw-sg"
  description = "Firewall con NAT"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-fw-sg" }
}

# Tráfico de la VPC que el firewall reenvía hacia Internet
resource "aws_vpc_security_group_ingress_rule" "fw_http" {
  security_group_id = aws_security_group.fw.id
  description       = "HTTP a reenviar"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "fw_https" {
  security_group_id = aws_security_group.fw.id
  description       = "HTTPS a reenviar"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "fw_icmp" {
  security_group_id = aws_security_group.fw.id
  description       = "ICMP a reenviar"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "fw_ssh_bastion" {
  security_group_id            = aws_security_group.fw.id
  description                  = "SSH desde el Bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "fw_from_it" {
  security_group_id            = aws_security_group.fw.id
  description                  = "TI llega a todas las subredes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.it.id
}

resource "aws_vpc_security_group_egress_rule" "fw_all" {
  security_group_id = aws_security_group.fw.id
  description       = "Salida a Internet"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "fw" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.management.id
  private_ip                  = cidrhost(var.management_subnet_cidr, 5)
  vpc_security_group_ids      = [aws_security_group.fw.id]
  key_name                    = var.key_name
  source_dest_check           = false
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/../scripts/fw.sh.tftpl", {
    vpc_cidr        = var.vpc_cidr
    management_cidr = var.management_subnet_cidr
    it_cidr         = var.it_subnet_cidr
  })

  tags = { Name = "${local.name}-fw" }
}
