output "cde_cluster_managed_identity_id" {
  description = "Azure resource ID of the CDE cluster user-assigned managed identity"
  value       = azurerm_user_assigned_identity.cde_cluster.id
}

output "cde_vc_managed_identity_id" {
  description = "Azure resource ID of the CDE virtual cluster user-assigned managed identity"
  value       = azurerm_user_assigned_identity.cde_vc.id
}
