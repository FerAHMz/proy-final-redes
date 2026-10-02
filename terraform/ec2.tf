data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IPs privadas fijas para que la documentación y las pruebas sean reproducibles.
# AWS reserva las primeras 4 direcciones y el broadcast de cada subred.

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.management.id
  private_ip             = cidrhost(var.management_subnet_cidr, 4)
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_name

  tags = { Name = "${local.name}-bastion" }
}

resource "aws_instance" "sales" {
  for_each = {
    "01" = cidrhost(var.sales_subnet_cidr, 10)
    "02" = cidrhost(var.sales_subnet_cidr, 11)
  }

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.sales.id
  private_ip                  = each.value
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sales.id]
  key_name                    = var.key_name

  tags = { Name = "${local.name}-sales-${each.key}" }
}

resource "aws_instance" "it" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.it.id
  private_ip                  = cidrhost(var.it_subnet_cidr, 10)
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.it.id]
  key_name                    = var.key_name

  tags = { Name = "${local.name}-it-01" }
}

resource "aws_instance" "datacenter" {
  count = var.datacenter_instance_count

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.datacenter.id
  private_ip                  = cidrhost(var.datacenter_subnet_cidr, 4 + count.index)
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.datacenter.id]
  key_name                    = var.key_name

  tags = { Name = format("${local.name}-dc-%02d", count.index + 1) }
}

resource "aws_instance" "guest" {
  count = var.create_guest_instance ? 1 : 0

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.guest.id
  private_ip                  = cidrhost(var.guest_subnet_cidr, 10)
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.guest.id]
  key_name                    = var.key_name

  tags = { Name = "${local.name}-guest-01" }
}
