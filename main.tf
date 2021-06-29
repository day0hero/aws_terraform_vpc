provider "aws" {
  region = var.region
}

module "ipi-vpc" {
  source                      = "./modules/ipi_vpc"
  vpc_name                    = "PROVIDE_VPC_NAME"
  cluster_name                = "PROVIDE_VPC_OR_CLUSTER_NAME"
  ssh_private_key_path        = "PATH_TO_SSH_PRIVATE_KEY"
  bastion_public_ssh_key_name = "PROVIDE_SSH_PUBLIC_KEY_NAME"
  bastion_instance_type       = "t3.large"
  bastion_volume_size         = "80"
  private_subnets             = local.private_subnets
  public_subnets              = local.public_subnets
  azs                         = local.azs
  dns_support_enabled         = true
  enable_dns_hostnames        = true
}
