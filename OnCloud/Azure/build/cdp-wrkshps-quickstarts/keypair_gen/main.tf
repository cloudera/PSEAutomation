# Terraform Block
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.1.0" # Specify a version or leave out for latest
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

# ------- Create SSH Keypair if input ssh_public_key variable is not specified
locals {
  # key pair value
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh_key[0].public_key_openssh
  keypair_name   = "${var.keypair_name}-keypair"
}

# Create and save a RSA key
resource "tls_private_key" "ssh_key" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to <keypair_name>-keypair.pem
resource "local_sensitive_file" "pem_file" {
  count                = var.ssh_public_key == "" ? 1 : 0
  filename             = "${var.keypair_name}-keypair.pem"
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.ssh_key[0].private_key_pem
}
