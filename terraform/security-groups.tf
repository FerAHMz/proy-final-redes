# ---------------------------------------------------------------------------
# Bastion: SSH solo desde la IP del administrador
# ---------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion-sg"
  description = "SSH desde la IP del administrador"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH administrador"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-bastion-sg" }
}

# ---------------------------------------------------------------------------
# Ventas: SSH desde Bastion, ICMP solo entre instancias de Ventas
# ---------------------------------------------------------------------------
resource "aws_security_group" "sales" {
  name        = "${local.name}-sales-sg"
  description = "Instancias de Ventas"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH desde Bastion"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "ICMP entre instancias de Ventas"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    self        = true
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-sales-sg" }
}

# ---------------------------------------------------------------------------
# TI: SSH desde Bastion
# ---------------------------------------------------------------------------
resource "aws_security_group" "it" {
  name        = "${local.name}-it-sg"
  description = "Instancias de TI"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH desde Bastion"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-it-sg" }
}

# ---------------------------------------------------------------------------
# Data Center: SSH desde Bastion y TI, ICMP solo desde TI
# Ventas y Visitas no tienen ninguna regla, por lo que quedan bloqueadas
# ---------------------------------------------------------------------------
resource "aws_security_group" "datacenter" {
  name        = "${local.name}-datacenter-sg"
  description = "Servidores del Data Center"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH desde Bastion y TI"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.bastion.id, aws_security_group.it.id]
  }

  ingress {
    description     = "ICMP desde TI"
    protocol        = "icmp"
    from_port       = -1
    to_port         = -1
    security_groups = [aws_security_group.it.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-datacenter-sg" }
}

# ---------------------------------------------------------------------------
# Visitas: sin reglas de entrada
# ---------------------------------------------------------------------------
resource "aws_security_group" "guest" {
  name        = "${local.name}-guest-sg"
  description = "Red de visitas, sin entrada"
  vpc_id      = aws_vpc.main.id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-guest-sg" }
}
