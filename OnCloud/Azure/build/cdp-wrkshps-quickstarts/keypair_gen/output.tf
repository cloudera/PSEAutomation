output "ssh_key_name_output" {
  value       = local.keypair_name
  description = "Logical name for the SSH key pair used by the workshop"
}

output "ssh_public_key_output" {
  value       = local.ssh_public_key
  description = "OpenSSH public key text for CDP Azure provisioning"
  sensitive   = true
}
