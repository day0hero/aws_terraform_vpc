provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "ocp-infradeploy"
    key = "openshift/"
    region = "us-gov-west-1"
    }
}

/*
module "ipi_vpc_airgap" {
  source                 = "./modules/ipi_vpc_airgap"
  vpc_cidr               = var.vpc_cidr
  vpc_name               = "jrickard"
  cluster_name           = "jrickard-airgap"
  private_ssh_key_path   = "~/.ssh/jrickard-bastion-unicorn.pem"
  ssh_key_name           = "jrickard-bastion-unicorn"
  bastion_instance_type  = "t3.large"
  bastion_volume_size    = "80"
  proxy_instance_type    = "t3.large"
  proxy_volume_size      = "40"
  registry_instance_type = "t3.large"
  registry_volume_size   = "150"
  private_subnets        = local.private_subnets
  public_subnets         = local.public_subnets
  azs                    = local.azs
  dns_support_enabled    = true
  enable_dns_hostnames   = true
}
*/

module "ipi_vpc_connected" {
  source                 = "./modules/ipi_vpc_connected"
  vpc_cidr               = var.vpc_cidr
  vpc_name               = "ocp-constructionzone"
  cluster_name           = "ocp-constructionzone"
  private_ssh_key_path   = "~/.ssh/jrickard-bastion-unicorn.pem"
  ssh_key_name           = "jrickard-bastion-unicorn"
  bastion_instance_type  = "t3.large"
  bastion_volume_size    = "80"
  proxy_instance_type    = "t3.large"
  proxy_volume_size      = "40"
  registry_instance_type = "t3.large"
  registry_volume_size   = "150"
  private_subnets        = local.private_subnets
  public_subnets         = local.public_subnets
  azs                    = local.azs
  dns_support_enabled    = true
  enable_dns_hostnames   = true
}
