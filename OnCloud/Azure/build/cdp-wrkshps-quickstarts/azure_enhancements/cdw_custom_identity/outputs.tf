output "cdw_managed_identity_id" {
  description = "Azure resource ID of the CDW user-assigned managed identity"
  value       = azurerm_user_assigned_identity.cdw.id
}

output "cdw_managed_identity_principal_id" {
  description = "Principal ID of the CDW user-assigned managed identity"
  value       = azurerm_user_assigned_identity.cdw.principal_id
}
