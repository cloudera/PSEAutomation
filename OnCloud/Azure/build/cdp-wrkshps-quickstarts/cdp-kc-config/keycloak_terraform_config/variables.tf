variable "workshop_name" {
  description = "Workshop name prefix for Keycloak resources"
  type        = string
  default     = "keycloak-server"
}

variable "domain" {
  description = "The root domain for which the SSL certificate will be issued."
  type        = string
  default     = "example.com"
}

variable "wildcard_fullchain" {
  description = "Base64-encoded fullchain certificate for the wildcard domain."
  type        = string
  default     = "---Private Key---"
}

variable "wildcard_privkey" {
  description = "Base64-encoded private key for the wildcard domain."
  type        = string
  default     = "---Private Key---"
}

variable "azure_region" {
  description = "Azure region in which Keycloak resources will be deployed"
  type        = string
  default     = "eastus"
}

variable "instance_type" {
  description = "Azure VM size for the Keycloak server"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "ssh_key_name" {
  description = "Logical SSH key name used for the Keycloak VM connection"
  type        = string
}

variable "ssh_public_key" {
  description = "OpenSSH public key installed on the Keycloak VM"
  type        = string
}

variable "kc_security_group" {
  description = "Network security group name for Keycloak"
  type        = string
  default     = "hol-default-nsg"
}

variable "local_ip" {
  description = "IPv4 CIDR allowed to access Keycloak"
  type        = string
  default     = "0.0.0.0/0"
}

variable "keycloak_admin_password" {
  description = "Admin password for Keycloak"
  type        = string
}
