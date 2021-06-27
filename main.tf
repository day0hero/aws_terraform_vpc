provider "aws" {
  region = var.region
}

module "ipi-vpc" {
  source               = "./modules/ipi_vpc"
  vpc_name             = "[ INSERT_VPC_NAME ]"
  cluster_name         = "[ INSERT_OCP_OR_VPC_NAME_HERE]"
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  azs                  = local.azs
  dns_support_enabled  = true
  enable_dns_hostnames = true
}
