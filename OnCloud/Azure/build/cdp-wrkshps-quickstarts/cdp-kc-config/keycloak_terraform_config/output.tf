output "elastic_ip" {
  value       = azurerm_public_ip.keycloak.ip_address
  description = "Public IP address of the Keycloak VM"
}
