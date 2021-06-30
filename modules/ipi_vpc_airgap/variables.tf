variable "region" {
  type    = string
  default = "us-gov-west-1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "vpc_tags" {
  type    = map(string)
  default = {}
}
variable "default_tags" {
  type    = map(string)
  default = {}
}
variable "dns_support_enabled" {
  type    = bool
  default = true
}
variable "enable_dns_hostnames" {
  type    = bool
  default = true
}
variable "instance_tenancy" {
  type    = string
  default = "default"
}
variable "vpc_name" {
  type    = string
  default = ""
}
variable "cluster_name" {
  type    = string
  default = ""
}
variable "map_public_ip_on_launch" {
  type    = bool
  default = true
}
variable "public_subnet_suffix" {
  description = "Suffix to append to public subnets name"
  type        = string
  default     = "public"
}
variable "private_subnet_suffix" {
  description = "Suffix to append to private subnets name"
  type        = string
  default     = "private"
}
variable "private_subnets" {
  type    = list(string)
  default = []
}
variable "public_subnets" {
  type    = list(string)
  default = []
}
//Availability Zone Variables
variable "azs" {
  type    = list(string)
  default = []
}

data "aws_availability_zones" "available" {
  state = "available"
}

//Local Variable Definitions
locals {
  vpc_cidr_ab          = "10.0"
  private_subnet_cidrs = 0
  max_private_subnets  = 3
  public_subnet_cidrs  = 3
  max_public_subnets   = 1
  azs                  = data.aws_availability_zones.available.names
}

locals {
  private_subnets = [
    for az in local.azs :
    "${local.vpc_cidr_ab}.${local.private_subnet_cidrs + index(local.azs, az)}.0/24"
    if index(local.azs, az) < local.max_private_subnets
  ]
  public_subnets = [
    for az in local.azs :
    "${local.vpc_cidr_ab}.${local.public_subnet_cidrs + index(local.azs, az)}.0/24"
    if index(local.azs, az) < local.max_public_subnets
  ]
}

// Bastion Node Variable Definition
variable "bastion_ami_id" {
  description = "Provide the ami-id to use for the bastion node: default is (RHEL8.3)"
  type        = string
  default     = "ami-0ac4e06a69870e5be"
}

variable "bastion_instance_type" {
  description = "Define the size of the bastion"
  type        = string
  default     = "t3.large"
}

variable "bastion_volume_size" {
  description = "Provide the desired size of the root volume"
  type        = string
  default     = "80"
}

// Proxy Node variable Definition
variable "proxy_ami_id" {
  description = "Provide the ami-id to use for the proxy node: default is (RHEL8.3)"
  type        = string
  default     = "ami-0ac4e06a69870e5be"
}

variable "proxy_instance_type" {
  description = "Define the size of the proxy"
  type        = string
  default     = "t3.large"
}

variable "proxy_volume_size" {
  description = "Provide the desired size of the root volume"
  type        = string
  default     = "50"
}

// Registry Node variable Definition
variable "registry_ami_id" {
  description = "Provide the ami-id to use for the registry node: default is (RHEL8.3)"
  type        = string
  default     = "ami-0ac4e06a69870e5be"
}

variable "registry_instance_type" {
  description = "Define the size of the registry"
  type        = string
  default     = "t3.large"
}

variable "registry_volume_size" {
  description = "Provide the desired size of the root volume"
  type        = string
  default     = "50"
}

// SSH User configuration
variable "ssh_user" {
  description = "Provide the username to ssh to instance with"
  type        = string
  default     = "ec2-user"
}

variable "public_ssh_key_name" {
  description = "Provide the name of the ssh key to use"
  type        = string
  default     = ""
}

variable "private_ssh_key_path" {
  description = "Path to private key to login to ec2"
  type        = string
  default     = ""
}
