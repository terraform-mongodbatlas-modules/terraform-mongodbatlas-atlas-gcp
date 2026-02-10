locals {
  # 41-entry static region mapping: Atlas format -> GCP format (CLOUDP-379586)
  # Entries verified against Atlas CLI (atlas clusters availableRegions) and gcloud (gcloud compute regions list)
  # using extract_regions.py (see just extract-regions / just validate-regions)
  atlas_to_gcp_region = {
    AFRICA_SOUTH_1            = "africa-south1"
    ASIA_EAST_2               = "asia-east2"
    ASIA_NORTHEAST_2          = "asia-northeast2"
    ASIA_NORTHEAST_3          = "asia-northeast3"
    ASIA_SOUTH_1              = "asia-south1"
    ASIA_SOUTH_2              = "asia-south2"
    ASIA_SOUTHEAST_2          = "asia-southeast2"
    AUSTRALIA_SOUTHEAST_1     = "australia-southeast1"
    AUSTRALIA_SOUTHEAST_2     = "australia-southeast2"
    EUROPE_CENTRAL_2          = "europe-central2"
    EUROPE_NORTH_1            = "europe-north1"
    EUROPE_SOUTHWEST_1        = "europe-southwest1"
    EUROPE_WEST_2             = "europe-west2"
    EUROPE_WEST_3             = "europe-west3"
    EUROPE_WEST_4             = "europe-west4"
    EUROPE_WEST_6             = "europe-west6"
    EUROPE_WEST_8             = "europe-west8"
    EUROPE_WEST_9             = "europe-west9"
    EUROPE_WEST_10            = "europe-west10"
    EUROPE_WEST_12            = "europe-west12"
    MIDDLE_EAST_CENTRAL_1     = "me-central1"
    MIDDLE_EAST_CENTRAL_2     = "me-central2"
    MIDDLE_EAST_WEST_1        = "me-west1"
    NORTH_AMERICA_NORTHEAST_1 = "northamerica-northeast1"
    NORTH_AMERICA_NORTHEAST_2 = "northamerica-northeast2"
    NORTH_AMERICA_SOUTH_1     = "northamerica-south1"
    SOUTH_AMERICA_EAST_1      = "southamerica-east1"
    SOUTH_AMERICA_WEST_1      = "southamerica-west1"
    US_EAST_4                 = "us-east4"
    US_EAST_5                 = "us-east5"
    US_SOUTH_1                = "us-south1"
    US_WEST_2                 = "us-west2"
    US_WEST_3                 = "us-west3"
    US_WEST_4                 = "us-west4"
    # Atlas geographic region aliases
    CENTRAL_US                = "us-central1"
    WESTERN_EUROPE            = "europe-west1"
    EASTERN_US                = "us-east1"
    WESTERN_US                = "us-west1"
    EASTERN_ASIA_PACIFIC      = "asia-east1"
    NORTHEASTERN_ASIA_PACIFIC = "asia-northeast1"
    SOUTHEASTERN_ASIA_PACIFIC = "asia-southeast1"
  }

  # Reverse mapping: GCP format -> Atlas format. Used in CLOUDP-379585 when calling Atlas APIs that require Atlas region format
  gcp_to_atlas_region = { for k, v in local.atlas_to_gcp_region : v => k }

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
