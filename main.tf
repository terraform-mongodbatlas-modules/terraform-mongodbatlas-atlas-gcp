# ─────────────────────────────────────────────────────────────────────────────
# Region Validations (format-aware, post-normalization)
# ─────────────────────────────────────────────────────────────────────────────

resource "terraform_data" "region_validations" {
  lifecycle {
    precondition {
      condition     = alltrue([for r in local._pl_normalized : r != null])
      error_message = "Unknown region in privatelink_endpoints. All regions must be valid Atlas (e.g. US_EAST_4) or GCP (e.g. us-east4) format per atlas_to_gcp_region."
    }
    precondition {
      condition     = length([for r in local._pl_normalized : r if r != null]) == length(distinct([for r in local._pl_normalized : r if r != null]))
      error_message = "Cross-format duplicate in privatelink_endpoints: two entries resolve to the same GCP region after normalization (e.g. us-east4 and US_EAST_4)."
    }
    precondition {
      condition     = alltrue([for r in local._pl_sr_normalized : r != null])
      error_message = "Unknown region in privatelink_endpoints_single_region. All regions must be valid Atlas or GCP format per atlas_to_gcp_region."
    }
    precondition {
      condition     = alltrue([for r in local._byoe_normalized : r != null])
      error_message = "Unknown region in privatelink_byoe_regions. All regions must be valid Atlas or GCP format per atlas_to_gcp_region."
    }
    precondition {
      condition = length(setintersection(
        toset([for r in local._pl_normalized : r if r != null]),
        toset([for r in local._byoe_normalized : r if r != null])
      )) == 0
      error_message = "Cross-format overlap between privatelink_endpoints and privatelink_byoe_regions: entries resolve to the same GCP region after normalization."
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

