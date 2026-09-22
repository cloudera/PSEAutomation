# Terraform Block
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}
# Provider Block
provider "azurerm" {
  features {}
  # profile = "default"
}

data "azurerm_storage_account" "log_storage" {
  name                = var.log_storage_account
  resource_group_name = var.resource_group_name
}

resource "azurerm_storage_management_policy" "log_lifecycle_policy" {
  storage_account_id = data.azurerm_storage_account.log_storage.id

  # Rule 1: Delete logs after 3 days
  rule {
    name    = "delete_logs_after_3_days"
    enabled = true

    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 3
      }
      version {
        delete_after_days_since_creation = 3
      }
    }
  }
}
