variable "env_prefix" {
  description = "CDP environment prefix (workshop name)"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group containing CDP storage and identities"
  type        = string
}

variable "data_storage_account" {
  description = "CDP datalake storage account name (model registry data path)"
  type        = string
}

variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}
