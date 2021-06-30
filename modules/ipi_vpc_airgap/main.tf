// Create the VPC
resource "aws_vpc" "cluster_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.dns_support_enabled
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy     = var.instance_tenancy

  tags = {
    Name = var.vpc_name
  }
}

// Private Subnet Configuration
resource "aws_subnet" "private_subnet" {
  count             = length(var.private_subnets) > 0 ? length(var.private_subnets) : 0
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null

  tags = merge(
    {
      "Name" = format("${var.cluster_name}-private-%s",
      element(var.azs, count.index)),
    },
    var.default_tags,
  )
}

// Route Table and Association - Private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id     = aws_vpc.cluster_vpc.id
  depends_on = [aws_instance.proxy]
  tags = merge(
    {
      "Name" = "${var.cluster_name}-private_net_rtbl",
    },
    var.default_tags,
  )
  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.proxy.id
  }
}

resource "aws_route_table_association" "private_net_route_table_assoc" {
  depends_on     = [aws_instance.proxy]
  count          = length(var.private_subnets)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}

// Public Subnet Configuration

resource "aws_subnet" "public-subnet" {
  count             = length(var.public_subnets) > 0 ? length(var.public_subnets) : 0
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null

  tags = merge(
    {
      "Name" = format("${var.cluster_name}-public-%s",
      element(var.azs, count.index)),
    },
    var.default_tags,
  )
}

// Route Table and Association - Public Subnets
resource "aws_route_table_association" "route_net" {
  count          = length(local.azs)
  route_table_id = aws_route_table.public-route-table.id
  subnet_id      = aws_subnet.public-subnet[count.index].id
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.cluster_vpc.id
  tags = merge(
    {
      "Name" = "${var.cluster_name}-public-rtbl",
    },
    var.default_tags,
  )

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  subnet_id      = aws_subnet.public-subnet[0].id
  route_table_id = aws_route_table.public-route-table.id
}

// Internet Gateway Configuration 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = merge(
    {
      "Name" = "${var.cluster_name}-public-igw",
    },
    var.default_tags,
  )
}

/*
Private endpoint configuration. Private endpoints are required for the installer and api 
to utilize the cloud integration. Without the endpoints instances provisioned on a private 
network will be unable to interrogate the cloud api. Endpoints can only be created for those
cloud services that have a private-link service - see list below:
- ec2
- elasticloadbalancing
- s3
*/

// private S3 endpoint
data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "private_s3" {
  vpc_id       = aws_vpc.cluster_vpc.id
  service_name = data.aws_vpc_endpoint_service.s3.service_name

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Principal": "*",
      "Action": "*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF

  tags = merge(
    {
      "Name" = format("${var.cluster_name}-pri-s3-vpce"),
    },
    var.default_tags,
  )
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  vpc_endpoint_id = aws_vpc_endpoint.private_s3.id
  route_table_id  = aws_route_table.private_route_table.id
}

// private ec2 endpoint
data "aws_vpc_endpoint_service" "ec2" {
  service = "ec2"
}

resource "aws_security_group" "private_ec2_api" {
  name   = "${var.cluster_name}-ec2-api"
  vpc_id = aws_vpc.cluster_vpc.id

  tags = merge(
    {
      "Name" = "${var.cluster_name}-private-ec2-api",
    },
    var.default_tags,
  )
}

resource "aws_security_group_rule" "private_ec2_ingress" {
  type = "ingress"

  from_port = 443
  to_port   = 443
  protocol  = "all"
  cidr_blocks = [
    "0.0.0.0/0"
  ]

  security_group_id = aws_security_group.private_ec2_api.id
}

resource "aws_security_group_rule" "private_ec2_api_egress" {
  type = "egress"

  from_port = 443
  to_port   = 443
  protocol  = "all"
  cidr_blocks = [
    "0.0.0.0/0"
  ]

  security_group_id = aws_security_group.private_ec2_api.id
}

resource "aws_vpc_endpoint" "private_ec2" {
  vpc_id            = aws_vpc.cluster_vpc.id
  service_name      = data.aws_vpc_endpoint_service.ec2.service_name
  vpc_endpoint_type = "Interface"

  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.private_ec2_api.id
  ]

  subnet_ids = aws_subnet.private_subnet.*.id
  tags = merge(
    {
      "Name" = "${var.cluster_name}-ec2-vpce"
    },
    var.default_tags,
  )
}

// private elb endpoint 
data "aws_vpc_endpoint_service" "elasticloadbalancing" {
  service = "elasticloadbalancing"
}

resource "aws_security_group" "private_elb_api" {
  name   = "${var.cluster_name}-elb-api"
  vpc_id = aws_vpc.cluster_vpc.id

  tags = merge(
    {
      "Name" = "${var.cluster_name}-private-elb-api",
    },
    var.default_tags,
  )
}

resource "aws_security_group_rule" "private_elb_ingress" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "all"
  cidr_blocks = [
    "0.0.0.0/0"
  ]

  security_group_id = aws_security_group.private_elb_api.id
}

resource "aws_security_group_rule" "private_elb_api_egress" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "all"
  cidr_blocks = [
    "0.0.0.0/0"
  ]

  security_group_id = aws_security_group.private_elb_api.id
}

resource "aws_vpc_endpoint" "elasticloadbalancing" {
  vpc_id              = aws_vpc.cluster_vpc.id
  service_name        = data.aws_vpc_endpoint_service.elasticloadbalancing.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  security_group_ids = [
    aws_security_group.private_ec2_api.id
  ]

  subnet_ids = aws_subnet.private_subnet.*.id
  tags = merge(
    {
      "Name" = "${var.cluster_name}-elb-vpce"
    },
    var.default_tags,
  )
}

/*
EC2 Configuration - For disconnected or airgapped installations a bastion, proxy and registry
node will be provisioned. The proxy is only used by the cluster to interact with the cloud api, the bastion
node is where image collection for the cluster takes place and is also where the the openshift-install 
command is executed from. 

The registry is a short term bootstrap service meant to bootstrap the cluster and provide a crutch until
a more robust, enterprise-grade registry is in place.
*/

// bastion instance configuration 
resource "aws_security_group" "bastion_sg" {
  name   = "${var.cluster_name}-bastion-sg"
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "${var.cluster_name}-bastion-sg"
  }
}

resource "aws_security_group_rule" "bastion_ingress_22" {
  security_group_id = aws_security_group.bastion_sg.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_security_group_rule" "bastion_ingress_6443" {
  security_group_id = aws_security_group.bastion_sg.id
  type              = "ingress"
  cidr_blocks       = [aws_vpc.cluster_vpc.cidr_block]
  protocol          = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_security_group_rule" "bastion_ingress_443" {
  security_group_id = aws_security_group.bastion_sg.id
  type              = "ingress"
  cidr_blocks       = [aws_vpc.cluster_vpc.cidr_block]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_security_group_rule" "bastion_egress" {
  type              = "egress"
  security_group_id = aws_security_group.bastion_sg.id
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
}

resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami_id
  instance_type               = var.bastion_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public-subnet[0].id

  tags = {
    Name = "${var.cluster_name}-bastion"
  }

  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  root_block_device {
    delete_on_termination = true
    volume_size           = var.bastion_volume_size
    volume_type           = "standard"
  }

  provisioner "file" {
    source      = "./scripts/bastion_config.bash"
    destination = "~/bastion_config.bash"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/bastion_config.bash",
      "sudo ./bastion_config.bash"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_ssh_key_path)
      host        = self.public_ip
    }
  }
}

/*
// Proxy Node
   Proxy node resource definition. The proxy is needed to allow the openshift installer
   to interact with the AWS API. 
*/

// Proxy EIP 
resource "aws_eip" "proxy_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

// Proxy Security Group and Rules
resource "aws_security_group" "proxy_sg" {
  name   = "${var.cluster_name}-proxy-sg"
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "${var.cluster_name}-proxy-sg"
  }
}

resource "aws_security_group_rule" "proxy_ingress_22" {
  security_group_id = aws_security_group.proxy_sg.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_security_group_rule" "proxy_ingress_3130" {
  security_group_id = aws_security_group.proxy_sg.id
  type              = "ingress"
  cidr_blocks       = [aws_vpc.cluster_vpc.cidr_block]
  protocol          = "tcp"
  from_port         = 3130
  to_port           = 3130
}

resource "aws_security_group_rule" "proxy_ingress_443" {
  security_group_id = aws_security_group.proxy_sg.id
  type              = "ingress"
  cidr_blocks       = [aws_vpc.cluster_vpc.cidr_block]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_security_group_rule" "proxy_egress" {
  type              = "egress"
  security_group_id = aws_security_group.proxy_sg.id
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
}

// Proxy instance creation 
resource "aws_instance" "proxy" {
  ami                         = var.proxy_ami_id
  instance_type               = var.proxy_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public-subnet[0].id

  tags = {
    Name = "${var.cluster_name}-proxy"
  }

  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.proxy_sg.id]

  root_block_device {
    delete_on_termination = true
    volume_size           = var.proxy_volume_size
    volume_type           = "standard"
  }

  provisioner "file" {
    source      = "./scripts/squid.bash"
    destination = "~/squid.bash"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/squid.sh",
      "sudo ./squid.sh"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_ssh_key_path)
      host        = self.public_ip
    }
  }
}

/*
//     Registry Node
//
*/

// Registry Security Group and Rules
resource "aws_security_group" "registry_sg" {
  name   = "${var.cluster_name}-registry-sg"
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "${var.cluster_name}-registry-sg"
  }
}

resource "aws_security_group_rule" "registry_ingress_22" {
  security_group_id = aws_security_group.registry_sg.id
  type              = "ingress"
  cidr_blocks       = [aws_vpc.cluster_vpc.cidr_block]
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_security_group_rule" "registry_ingress_5000" {
  security_group_id = aws_security_group.registry_sg.id
  type              = "ingress"
  cidr_blocks       = [aws_vpc.cluster_vpc.cidr_block]
  protocol          = "tcp"
  from_port         = 5000
  to_port           = 5000
}

resource "aws_security_group_rule" "registry_egress" {
  type              = "egress"
  security_group_id = aws_security_group.registry_sg.id
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
}

// Registry instance creation 
resource "aws_instance" "registry" {
  ami                         = var.registry_ami_id
  instance_type               = var.registry_instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.private_subnet[0].id

  tags = {
    Name = "${var.cluster_name}-registry"
  }

  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.registry_sg.id]

  root_block_device {
    delete_on_termination = true
    volume_size           = var.registry_volume_size
    volume_type           = "standard"
  }
}

// Terraform Outputs
