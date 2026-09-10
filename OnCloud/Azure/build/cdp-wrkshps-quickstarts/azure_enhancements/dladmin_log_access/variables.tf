variable "env_prefix" {
  description = "CDP environment prefix (workshop name)"
  type        = string
}

variable "log_storage_account" {
  description = "Azure storage account for CDP logs"
  type        = string
}

variable "log_storage_container" {
  description = "Azure blob container for CDP logs"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group containing CDP storage and identities"
  type        = string
}

variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}
