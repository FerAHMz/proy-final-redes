# Pública: local + 0.0.0.0/0 -> IGW, solo para Administración
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "management" {
  subnet_id      = aws_subnet.management.id
  route_table_id = aws_route_table.public.id
}

# Privada: ruta local + salida a Internet por el firewall (solo salida;
# desde Internet no hay forma de entrar a estas subredes)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.fw.primary_network_interface_id
  }

  tags = { Name = "${local.name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each = {
    sales      = aws_subnet.sales.id
    guest      = aws_subnet.guest.id
    it         = aws_subnet.it.id
    datacenter = aws_subnet.datacenter.id
    hr         = aws_subnet.hr.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private.id
}

# Tabla principal que AWS crea con la VPC; ninguna subred la usa porque
# todas tienen asociación explícita. Solo se adopta para nombrarla.
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = { Name = "${local.name}-main-rt-unused" }
}
