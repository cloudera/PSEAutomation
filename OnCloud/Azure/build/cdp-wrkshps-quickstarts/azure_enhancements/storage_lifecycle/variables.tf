variable "azure_region" {
  description = "Azure region for the storage account"
  type        = string
}

variable "log_storage_account" {
  description = "Azure storage account name for CDP logs"
  type        = string
}

variable "log_storage_container" {
  description = "Azure storage container name for CDP logs"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group containing the log storage account"
  type        = string
}
