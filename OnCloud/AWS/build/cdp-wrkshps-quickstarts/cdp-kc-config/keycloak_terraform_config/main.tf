# Terraform Block
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.65.0"
    }
  }
}
# Provider Block
provider "aws" {
  region = var.aws_region
  # profile = "default" 
}

resource "aws_instance" "keycloak-server" {
  ami           = var.amis[var.aws_region]
  instance_type = var.instance_type
  user_data = templatefile("${path.module}/install-docker.sh", {
    keycloak_admin_password = var.keycloak_admin_password,
    domain                  = var.domain,
    workshop_name           = var.workshop_name,
    wildcard_fullchain      = var.wildcard_fullchain,
    wildcard_privkey        = var.wildcard_privkey,
  })
  key_name               = var.instance_keypair
  vpc_security_group_ids = [aws_security_group.vpc-ssh-web.id]
  tags = {
    "Name" = "${var.workshop_name}-keyc"
  }
}
resource "aws_eip" "kc_elastic_ip" {
  instance = aws_instance.keycloak-server.id
}

resource "aws_security_group" "vpc-ssh-web" {
  name        = var.kc_security_group
  description = "Allow Keycloak access from configured CIDRs"

  lifecycle {
    create_before_destroy = true
  }

  dynamic "ingress" {
    for_each = length(local.trusted_cidrs) > 0 ? [1] : []
    content {
      description = "Allow all traffic from trusted CIDRs"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = local.trusted_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(local.public_cidrs) > 0 ? local.public_ports : toset([])
    content {
      description = "Allow Keycloak port ${ingress.value} from public CIDR"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = local.public_cidrs
    }
  }

  egress {
    description = "Allow All Outbound Connection"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  configured_cidrs = distinct(var.local_ips)
  public_cidrs     = [for cidr in local.configured_cidrs : cidr if cidr == "0.0.0.0/0"]
  trusted_cidrs    = [for cidr in local.configured_cidrs : cidr if cidr != "0.0.0.0/0"]
  public_ports     = toset([22, 80, 443, 5000])
}
