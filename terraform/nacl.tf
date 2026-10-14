# NACL de Visitas (Fase 2): la subred de invitados sale a Internet pero no
# llega a ninguna otra subred. Solo TI puede entrar. Es stateless, por eso
# se permiten explícitamente las respuestas hacia TI.
resource "aws_network_acl" "guest" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.guest.id]

  # Respuestas a conexiones iniciadas por TI
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = var.it_subnet_cidr
    from_port  = 0
    to_port    = 0
  }

  # Nada hacia el resto de la VPC
  egress {
    rule_no    = 110
    action     = "deny"
    protocol   = "-1"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Internet (sale por el firewall)
  egress {
    rule_no    = 200
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # TI puede entrar a Visitas
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = var.it_subnet_cidr
    from_port  = 0
    to_port    = 0
  }

  # Nada más de la VPC entra
  ingress {
    rule_no    = 110
    action     = "deny"
    protocol   = "-1"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Respuestas desde Internet (llegan con la IP del servidor remoto)
  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${local.name}-guest-nacl" }
}
