data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "barrilete"
  az   = data.aws_availability_zones.available.names[0]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Course      = "CC3067-Redes"
  }
}
