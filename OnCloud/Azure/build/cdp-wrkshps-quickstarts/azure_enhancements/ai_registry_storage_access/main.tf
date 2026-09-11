# Storage roles for Cloudera AI Model Registry on the datalake storage account.
# https://docs.cloudera.com/cdp-public-cloud/cloud/requirements-azure/topics/mc-az-minimal-setup-for-cloud-storage.html
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

data "azurerm_storage_account" "datalake" {
  name                = var.data_storage_account
  resource_group_name = var.resource_group_name
}

data "azurerm_user_assigned_identity" "datalake_admin" {
  name                = "${var.env_prefix}-dladmin-identity"
  resource_group_name = var.resource_group_name
}

data "azurerm_user_assigned_identity" "logger" {
  name                = "${var.env_prefix}-logs-identity"
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "dladmin_datalake_blob_owner" {
  scope                = data.azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_user_assigned_identity.datalake_admin.principal_id

  description = "HoL enhancement: datalake admin blob owner on datalake account for AI Registry"
}

resource "azurerm_role_assignment" "dladmin_datalake_storage_account_contributor" {
  scope                = data.azurerm_storage_account.datalake.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_user_assigned_identity.datalake_admin.principal_id

  description = "HoL enhancement: datalake admin storage account contributor for AI Registry"
}

resource "azurerm_role_assignment" "logger_datalake_storage_account_contributor" {
  scope                = data.azurerm_storage_account.datalake.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_user_assigned_identity.logger.principal_id

  description = "HoL enhancement: logger storage account contributor for AI Registry modelregistry path"
}

resource "azurerm_role_assignment" "logger_datalake_blob_contributor" {
  scope                = data.azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.logger.principal_id

  description = "HoL enhancement: logger blob contributor on datalake account for AI Registry modelregistry path"
}
