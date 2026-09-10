# CDW user-assigned identity and custom role per:
# https://docs.cloudera.com/data-warehouse/cloud/azure-environments/topics/dw-azure-environments-minimum-permissions.html
# Legacy single-server PostgreSQL actions are omitted (not available on Azure today).

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

locals {
  cdw_role_actions = [
    "Microsoft.Resources/deployments/cancel/action",
    "Microsoft.Resources/deployments/validate/action",
    "Microsoft.ContainerService/managedClusters/write",
    "Microsoft.ContainerService/managedClusters/agentPools/write",
    "Microsoft.ContainerService/managedClusters/read",
    "Microsoft.ContainerService/managedClusters/agentPools/read",
    "Microsoft.ContainerService/managedClusters/accessProfiles/listCredential/action",
    "Microsoft.ContainerService/managedClusters/delete",
    "Microsoft.ContainerService/managedClusters/rotateClusterCertificates/action",
    "Microsoft.DBforPostgreSQL/flexibleServers/read",
    "Microsoft.DBforPostgreSQL/flexibleServers/write",
    "Microsoft.DBforPostgreSQL/flexibleServers/delete",
    "Microsoft.DBforPostgreSQL/flexibleServers/firewallRules/write",
    "Microsoft.DBforPostgreSQL/flexibleServers/firewallRules/read",
    "Microsoft.DBforPostgreSQL/flexibleServers/firewallRules/delete",
    "Microsoft.DBforPostgreSQL/flexibleServers/configurations/read",
    "Microsoft.DBforPostgreSQL/flexibleServers/configurations/write",
    "Microsoft.DBforPostgreSQL/flexibleServers/databases/read",
    "Microsoft.DBforPostgreSQL/flexibleServers/databases/write",
    "Microsoft.DBforPostgreSQL/flexibleServers/databases/delete",
    "Microsoft.Network/privateDnsZones/A/read",
    "Microsoft.Network/privateDnsZones/A/write",
    "Microsoft.Network/privateDnsZones/A/delete",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
    "Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action",
    "Microsoft.Network/routeTables/read",
    "Microsoft.Network/routeTables/write",
    "Microsoft.Network/routeTables/routes/read",
    "Microsoft.Network/routeTables/routes/write",
    "Microsoft.Network/routeTables/join/action",
    "Microsoft.Network/natGateways/join/action",
    "Microsoft.Network/virtualNetworks/subnets/joinLoadBalancer/action",
    "Microsoft.Network/privateDnsZones/write",
    "Microsoft.Network/privateDnsZones/read",
    "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
    "Microsoft.Network/privateEndpoints/write",
    "Microsoft.Network/privateEndpoints/read",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write",
    "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/delete",
    "Microsoft.Network/privateDnsZones/join/action",
  ]
}

resource "azurerm_user_assigned_identity" "cdw" {
  name                = "${var.env_prefix}-cdw-identity"
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_definition" "cdw" {
  name        = "${var.env_prefix}-cdw-custom-role"
  scope       = data.azurerm_resource_group.cdp.id
  description = "CDW minimum permissions for ${var.env_prefix} (HoL automation)"

  permissions {
    actions = local.cdw_role_actions
  }
}

resource "azurerm_role_assignment" "cdw" {
  scope              = data.azurerm_resource_group.cdp.id
  role_definition_id = azurerm_role_definition.cdw.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.cdw.principal_id

  description = "HoL enhancement: CDW custom role for ${var.env_prefix}-cdw-identity"
}
