# Variables
variable "keypair_name" {
  description = "Prefix used for the generated SSH key pair"
  type        = string
}

variable "ssh_public_key" {
  description = "Optional existing SSH public key. If empty, a new key pair is generated."
  type        = string
  default     = ""
}
