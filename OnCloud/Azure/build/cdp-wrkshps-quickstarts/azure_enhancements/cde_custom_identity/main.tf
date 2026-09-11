# CDE user-assigned identities for cluster and virtual cluster workloads.
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "cdp" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "log_storage" {
  name                = var.log_storage_account
  resource_group_name = var.resource_group_name
}

locals {
  log_container_scope = "${data.azurerm_storage_account.log_storage.id}/blobServices/default/containers/${var.log_storage_container}"
}

resource "azurerm_user_assigned_identity" "cde_cluster" {
  name                = "${var.env_prefix}-cde-cluster-identity"
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "cde_vc" {
  name                = "${var.env_prefix}-cde-vc-identity"
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "cde_cluster_log_contributor" {
  scope                = local.log_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.cde_cluster.principal_id

  description = "HoL enhancement: allow CDE cluster identity PutBlob on CDP log container"
}

resource "azurerm_role_assignment" "cde_vc_log_contributor" {
  scope                = local.log_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.cde_vc.principal_id

  description = "HoL enhancement: allow CDE VC identity PutBlob on CDP log container"
}

resource "azurerm_role_assignment" "cde_cluster_managed_identity_operator" {
  scope                = data.azurerm_resource_group.cdp.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.cde_cluster.principal_id

  description = "HoL enhancement: allow CDE cluster identity to use managed identities in the CDP resource group"
}

resource "azurerm_role_assignment" "cde_vc_managed_identity_operator" {
  scope                = data.azurerm_resource_group.cdp.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.cde_vc.principal_id

  description = "HoL enhancement: allow CDE VC identity to use managed identities in the CDP resource group"
}
