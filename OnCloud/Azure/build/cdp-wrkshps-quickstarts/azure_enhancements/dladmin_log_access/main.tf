# Grant datalake admin managed identity blob write access on the CDP log container.
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

data "azurerm_storage_account" "log_storage" {
  name                = var.log_storage_account
  resource_group_name = var.resource_group_name
}

data "azurerm_user_assigned_identity" "datalake_admin" {
  name                = "${var.env_prefix}-dladmin-identity"
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "datalake_admin_log_contributor" {
  scope                = "${data.azurerm_storage_account.log_storage.id}/blobServices/default/containers/${var.log_storage_container}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.datalake_admin.principal_id

  description = "HoL enhancement: allow datalake admin PutBlob on CDP log container"
}
