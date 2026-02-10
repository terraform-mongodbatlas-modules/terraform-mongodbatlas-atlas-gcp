locals {
  atlas_to_gcp_region = var.atlas_to_gcp_region
  gcp_to_atlas_region = { for k, v in var.atlas_to_gcp_region : v => k }

  # Normalize regions to GCP format for precondition validation (null = unknown)
  _pl_normalized = [
    for ep in var.privatelink_endpoints :
    lookup(local.atlas_to_gcp_region, ep.region,
    contains(values(local.atlas_to_gcp_region), ep.region) ? ep.region : null)
  ]
  _pl_sr_normalized = [
    for ep in var.privatelink_endpoints_single_region :
    lookup(local.atlas_to_gcp_region, ep.region,
    contains(values(local.atlas_to_gcp_region), ep.region) ? ep.region : null)
  ]
  _byoe_normalized = [
    for v in values(var.privatelink_byoe_regions) :
    lookup(local.atlas_to_gcp_region, v,
    contains(values(local.atlas_to_gcp_region), v) ? v : null)
  ]

  # Cloud provider access: skip when only privatelink is configured
  privatelink_configured = length(var.privatelink_endpoints) > 0 || length(var.privatelink_endpoints_single_region) > 0 || length(var.privatelink_byoe_regions) > 0
  skip_cloud_provider_access = (
    !var.encryption.enabled &&
    !var.backup_export.enabled &&
    local.privatelink_configured
  )

  create_cloud_provider_access = var.cloud_provider_access.create && !local.skip_cloud_provider_access

  role_id = local.create_cloud_provider_access ? (
    module.cloud_provider_access[0].role_id
  ) : try(var.cloud_provider_access.existing.role_id, null)

  service_account_for_atlas = local.create_cloud_provider_access ? (
    module.cloud_provider_access[0].service_account_for_atlas
  ) : try(var.cloud_provider_access.existing.service_account_for_atlas, null)

  # Encryption role: dedicated or shared
  create_encryption_dedicated_role = var.encryption.enabled && var.encryption.dedicated_role_enabled
  encryption_role_id = local.create_encryption_dedicated_role ? (
    module.encryption_cloud_provider_access[0].role_id
  ) : local.role_id
  encryption_service_account = local.create_encryption_dedicated_role ? (
    module.encryption_cloud_provider_access[0].service_account_for_atlas
  ) : local.service_account_for_atlas

  # Backup export role: dedicated or shared
  create_backup_export_dedicated_role = var.backup_export.enabled && var.backup_export.dedicated_role_enabled
  backup_export_role_id = local.create_backup_export_dedicated_role ? (
    module.backup_export_cloud_provider_access[0].role_id
  ) : local.role_id
  backup_export_service_account = local.create_backup_export_dedicated_role ? (
    module.backup_export_cloud_provider_access[0].service_account_for_atlas
  ) : local.service_account_for_atlas

  # PrivateLink: convert lists to maps for for_each
  privatelink_endpoints_map               = { for ep in var.privatelink_endpoints : ep.region => ep }
  privatelink_endpoints_single_region_map = { for idx, ep in var.privatelink_endpoints_single_region : tostring(idx) => ep }
  privatelink_module_managed              = merge(local.privatelink_endpoints_map, local.privatelink_endpoints_single_region_map)
  privatelink_endpoints_all = merge(
    local.privatelink_module_managed,
    { for k, region in var.privatelink_byoe_regions : k => { region = region, subnetwork = "", labels = {} } }
  )
  privatelink_module_calls = merge(
    local.privatelink_module_managed,
    { for k, region in var.privatelink_byoe_regions : k => { region = region, subnetwork = "", labels = {} } if contains(keys(var.privatelink_byoe), k) }
  )

  # Normalize regions for accurate counting (handles mixed GCP/Atlas format input)
  privatelink_all_regions = toset([
    for k, value in local.privatelink_endpoints_all :
    lookup(local.atlas_to_gcp_region, value.region, value.region)
  ])
  enable_regional_mode = length(local.privatelink_all_regions) > 1

}
