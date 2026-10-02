# Todas las subredes en una sola AZ para reducir costos en la Fase 1.
# 192.168.10.192/26 queda sin asignar como reserva de crecimiento.

resource "aws_subnet" "sales" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.sales_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-sales-subnet" }
}

resource "aws_subnet" "guest" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.guest_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-guest-subnet" }
}

resource "aws_subnet" "it" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.it_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-it-subnet" }
}

resource "aws_subnet" "datacenter" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.datacenter_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-datacenter-subnet" }
}

# Única subred pública, aloja el Bastion
resource "aws_subnet" "management" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.management_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-management-subnet" }
}
