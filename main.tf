# ─────────────────────────────────────────────────────────────────────────────
# Cloud Provider Access
# ─────────────────────────────────────────────────────────────────────────────

module "cloud_provider_access" {
  count      = local.create_cloud_provider_access ? 1 : 0
  source     = "./modules/cloud_provider_access"
  project_id = var.project_id
}

module "encryption_cloud_provider_access" {
  count      = local.create_encryption_dedicated_role ? 1 : 0
  source     = "./modules/cloud_provider_access"
  project_id = var.project_id
}

module "backup_export_cloud_provider_access" {
  count      = local.create_backup_export_dedicated_role ? 1 : 0
  source     = "./modules/cloud_provider_access"
  project_id = var.project_id
}

# ─────────────────────────────────────────────────────────────────────────────
# PrivateLink
# ─────────────────────────────────────────────────────────────────────────────

resource "mongodbatlas_private_endpoint_regional_mode" "this" {
  count      = local.enable_regional_mode ? 1 : 0
  project_id = var.project_id
  enabled    = true
}

resource "mongodbatlas_privatelink_endpoint" "this" {
  for_each      = local.privatelink_endpoints_all
  project_id    = var.project_id
  provider_name = "GCP"
  region        = lookup(local.gcp_to_atlas_region, each.value.region, each.value.region)
  # TODO(d06-13): uncomment when provider ~> 2.7 is released (target Feb 18)
  # port_mapping_enabled = true

  depends_on = [mongodbatlas_private_endpoint_regional_mode.this]
}

