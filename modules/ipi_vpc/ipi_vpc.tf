resource "aws_vpc" "cluster_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.dns_support_enabled
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy     = var.instance_tenancy

  tags = {
    Name = var.vpc_name
  }
}

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

resource "aws_eip" "ngw_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw_eip.id
  subnet_id     = aws_subnet.public-subnet[0].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.cluster_name}-ngw"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id     = aws_vpc.cluster_vpc.id
  depends_on = [aws_nat_gateway.ngw]
  tags = merge(
    {
      "Name" = "${var.cluster_name}-private_net_rtbl",
    },
    var.default_tags,
  )
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_route_table_association" "private_net_route_table_assoc" {
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

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = merge(
    {
      "Name" = "${var.cluster_name}-public-inet-gw",
    },
    var.default_tags,
  )
}

# private S3 endpoint
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
  //  count =  length(var.aws_azs)

  vpc_endpoint_id = aws_vpc_endpoint.private_s3.id
  route_table_id  = aws_route_table.private_route_table.id
}

## private ec2 endpoint
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
  protocol  = "tcp"
  cidr_blocks = [
    "aws_vpc.cluster_vpc.cidr_block"
  ]

  security_group_id = aws_security_group.private_ec2_api.id
}

resource "aws_security_group_rule" "private_ec2_api_egress" {
  type = "egress"

  from_port = 0
  to_port   = 0
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
  protocol  = "tcp"
  cidr_blocks = [
    "aws_vpc.cluster_vpc.cidr_block"
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

  key_name               = var.bastion_public_ssh_key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  root_block_device {
    delete_on_termination = true
    volume_size           = var.bastion_volume_size
    volume_type           = "standard"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -LfO http://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-install-linux.tar.gz",
      "curl -LfO http://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-client-linux.tar.gz",
      "sudo tar xvf openshift-install-linux.tar.gz -C /usr/local/bin",
      "sudo tar xvf openshift-client-linux.tar.gz -C /usr/local/bin",
      "rm -rf ~/openshift-*",
      "mkdir -p ~/.aws",
      "sudo dnf install -y podman git vim tmux",
      "sudo dnf update -y"
    ]

    connection {
      type        = "ssh"
      user        = var.bastion_ssh_user
      private_key = file(var.ssh_private_key_path)
      host        = self.public_ip
    }
  }
}
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
