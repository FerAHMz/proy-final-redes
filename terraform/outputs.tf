output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "management_subnet_id" {
  value = aws_subnet.management.id
}

output "sales_subnet_id" {
  value = aws_subnet.sales.id
}

output "guest_subnet_id" {
  value = aws_subnet.guest.id
}

output "it_subnet_id" {
  value = aws_subnet.it.id
}

output "datacenter_subnet_id" {
  value = aws_subnet.datacenter.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "sales_01_private_ip" {
  value = aws_instance.sales["01"].private_ip
}

output "sales_02_private_ip" {
  value = aws_instance.sales["02"].private_ip
}

output "it_01_private_ip" {
  value = aws_instance.it.private_ip
}

output "datacenter_private_ips" {
  value = aws_instance.datacenter[*].private_ip
}

output "guest_01_private_ip" {
  value = one(aws_instance.guest[*].private_ip)
}

output "ssh_bastion_command" {
  value = "ssh -i <key.pem> ec2-user@${aws_instance.bastion.public_ip}"
}

output "ssh_sales_01_command" {
  value = "ssh -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@${aws_instance.sales["01"].private_ip}"
}
