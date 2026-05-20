locals {
  create_gcs_bucket   = var.create_gcs_bucket.enabled
  default_name        = "atlas-logs-${var.project_id}${var.create_gcs_bucket.name_suffix}"
  resolved_name       = var.create_gcs_bucket.name != "" ? var.create_gcs_bucket.name : local.default_name
  default_bucket_name = local.create_gcs_bucket ? google_storage_bucket.atlas[0].name : var.bucket_name
  integration_bucket_names = [
    for i in var.integrations : coalesce(i.bucket_name, local.default_bucket_name)
  ]
  unique_target_buckets = toset(local.integration_bucket_names)
  byo_buckets_to_lookup = {
    for name in local.unique_target_buckets : name => name
    if !local.create_gcs_bucket || name != local.default_bucket_name
  }
}

data "google_storage_bucket" "byo" {
  for_each = local.byo_buckets_to_lookup
  name     = each.value
}

resource "google_storage_bucket" "atlas" {
  count                       = local.create_gcs_bucket ? 1 : 0
  name                        = local.resolved_name
  location                    = var.create_gcs_bucket.location
  storage_class               = var.create_gcs_bucket.storage_class
  force_destroy               = var.create_gcs_bucket.force_destroy
  uniform_bucket_level_access = var.create_gcs_bucket.uniform_bucket_level_access
  public_access_prevention    = var.create_gcs_bucket.public_access_prevention
  labels                      = var.labels

  versioning {
    enabled = var.create_gcs_bucket.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = local.create_gcs_bucket ? [1] : []

    content {
      action {
        type = "Delete"
      }
      condition {
        age = coalesce(var.create_gcs_bucket.expiration_days, 90)
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.resolved_name) >= 3 && length(local.resolved_name) <= 63
      error_message = "Bucket name '${local.resolved_name}' (${length(local.resolved_name)} chars) must be 3-63 characters."
    }
  }
}

resource "google_storage_bucket_iam_member" "atlas" {
  for_each = var.skip_iam_bindings ? toset([]) : local.unique_target_buckets

  bucket = each.value
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.atlas_service_account_email}"
}

resource "time_sleep" "iam_propagation" {
  depends_on = [
    google_storage_bucket_iam_member.atlas,
    google_storage_bucket.atlas,
  ]
  create_duration = "30s"
}

resource "mongodbatlas_log_integration" "this" {
  count = length(var.integrations)

  project_id  = var.project_id
  type        = "GCS_LOG_EXPORT"
  role_id     = var.role_id
  log_types   = var.integrations[count.index].log_types
  prefix_path = var.integrations[count.index].prefix_path
  bucket_name = local.integration_bucket_names[count.index]

  depends_on = [time_sleep.iam_propagation]
}
