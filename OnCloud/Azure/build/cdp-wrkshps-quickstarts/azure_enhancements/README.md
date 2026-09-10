# Azure Enhancements

Optional post-provision enhancements for CDP Azure environments.

## storage_lifecycle

Applies a lifecycle management policy to the CDP log storage container so objects under `logs/` are removed after three days.

## dladmin_log_access

Assigns **Storage Blob Data Contributor** on the CDP log container to the `${env_prefix}-dladmin-identity` managed identity. This mirrors the log identity write access and ensures datalake admin can PutBlob on the logs path when needed.

## cdw_custom_identity

When `ENABLE_DATA_SERVICES` includes `CDW`, creates `${env_prefix}-cdw-identity` and assigns a custom role with [CDW minimum permissions](https://docs.cloudera.com/data-warehouse/cloud/azure-environments/topics/dw-azure-environments-minimum-permissions.html). The following legacy single-server PostgreSQL actions are excluded because they are not available on Azure today:

- `Microsoft.DBforPostgreSQL/servers/virtualNetworkRules/write`
- `Microsoft.DBforPostgreSQL/servers/databases/write`

The managed identity resource ID is passed to `enable-cdw.yml` as `azure.managed_identity`.

## CAI NFS (via CDP Terraform)

When `ENABLE_DATA_SERVICES` includes `CAI` or `PROVISION_CAII` is `yes`, `provision_cdp()` patches `cdp-tf-quickstarts/azure` to enable `create_azure_cml_nfs` on the prereqs module. This uses Cloudera's `terraform-azure-nfs` module to create:

- Premium `FileStorage` account with secure transfer disabled (required for NFS v4.1)
- NFS file share with private endpoints in each CDP workload subnet
- Private DNS zone `privatelink.file.core.windows.net` linked to the CDP VNet
