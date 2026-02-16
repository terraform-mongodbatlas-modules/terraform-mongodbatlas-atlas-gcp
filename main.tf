# ─────────────────────────────────────────────────────────────────────────────
# Region Validations (format-aware, post-normalization)
# ─────────────────────────────────────────────────────────────────────────────

resource "terraform_data" "region_validations" {
  lifecycle {
    precondition {
      condition     = length(local._pl_unknown) == 0
      error_message = "Unknown region(s) in privatelink_endpoints: [${join(", ", local._pl_unknown)}]. Must be valid Atlas (e.g. US_EAST_4) or GCP (e.g. us-east4) format."
    }
    precondition {
      condition     = length(local._pl_duplicates) == 0
      error_message = "Cross-format duplicate(s) in privatelink_endpoints, same GCP region after normalization: [${join(", ", local._pl_duplicates)}]."
    }
    precondition {
      condition     = length(local._pl_sr_unknown) == 0
      error_message = "Unknown region(s) in privatelink_endpoints_single_region: [${join(", ", local._pl_sr_unknown)}]."
    }
    precondition {
      condition     = length(local._byoe_unknown) == 0
      error_message = "Unknown region(s) in privatelink_byoe_regions: [${join(", ", local._byoe_unknown)}]."
    }
    precondition {
      condition     = length(local._pl_byoe_overlap) == 0
      error_message = "Overlap between privatelink_endpoints and privatelink_byoe_regions after normalization: [${join(", ", local._pl_byoe_overlap)}]."
    }
  }
}

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
# Encryption
# ─────────────────────────────────────────────────────────────────────────────

module "encryption" {
  count  = var.encryption.enabled ? 1 : 0
  source = "./modules/encryption"

  project_id                  = var.project_id
  role_id                     = local.encryption_role_id
  atlas_service_account_email = local.encryption_service_account
  key_version_resource_id     = var.encryption.key_version_resource_id
  labels                      = var.gcp_tags

  create_kms_key = merge(var.encryption.create_kms_key, {
    location = lookup(
      local.atlas_to_gcp_region,
      var.encryption.create_kms_key.location,
      var.encryption.create_kms_key.location
    )
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Backup Export
# ─────────────────────────────────────────────────────────────────────────────

module "backup_export" {
  count  = var.backup_export.enabled ? 1 : 0
  source = "./modules/backup_export"

  project_id                  = var.project_id
  role_id                     = local.backup_export_role_id
  atlas_service_account_email = local.backup_export_service_account
  bucket_name                 = var.backup_export.bucket_name
  labels                      = var.gcp_tags

  create_bucket = merge(var.backup_export.create_bucket, {
    location = lookup(
      local.atlas_to_gcp_region,
      var.backup_export.create_bucket.location,
      var.backup_export.create_bucket.location
    )
  })

  depends_on = [module.cloud_provider_access, module.backup_export_cloud_provider_access]
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
  for_each             = local.privatelink_endpoints_all
  project_id           = var.project_id
  provider_name        = "GCP"
  region               = lookup(local.gcp_to_atlas_region, each.value.region, each.value.region)
  port_mapping_enabled = true

  depends_on = [mongodbatlas_private_endpoint_regional_mode.this]
}

module "privatelink" {
  source   = "./modules/privatelink"
  for_each = local.privatelink_module_calls

  project_id              = var.project_id
  gcp_region              = lookup(local.atlas_to_gcp_region, each.value.region, each.value.region)
  private_link_id         = mongodbatlas_privatelink_endpoint.this[each.key].private_link_id
  service_attachment_name = mongodbatlas_privatelink_endpoint.this[each.key].service_attachment_names[0]

  subnetwork  = contains(keys(local.privatelink_module_managed), each.key) ? { id = each.value.subnetwork } : null
  byo         = try(var.privatelink_byoe[each.key], null)
  name_prefix = "atlas-psc-${replace(lower(each.key), "_", "-")}-"

  labels = merge(var.gcp_tags, each.value.labels)

  depends_on = [mongodbatlas_private_endpoint_regional_mode.this]
}
