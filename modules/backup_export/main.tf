locals {
  create_gcs_bucket = var.create_gcs_bucket.enabled
  default_name      = "atlas-backup-${var.project_id}${var.create_gcs_bucket.name_suffix}"
  resolved_name     = var.create_gcs_bucket.name != "" ? var.create_gcs_bucket.name : local.default_name
  bucket_name       = local.create_gcs_bucket ? google_storage_bucket.atlas[0].name : var.bucket_name
  bucket_location = (
    local.create_gcs_bucket ? var.create_gcs_bucket.location : data.google_storage_bucket.user_provided[0].location
  )
  bucket_url = local.create_gcs_bucket ? (
    google_storage_bucket.atlas[0].url
  ) : data.google_storage_bucket.user_provided[0].url
}

data "google_storage_bucket" "user_provided" {
  count = local.create_gcs_bucket ? 0 : 1
  name  = var.bucket_name
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
    for_each = var.create_gcs_bucket.expiration_days > 0 ? [1] : []

    content {
      action {
        type = "Delete"
      }
      condition {
        age = var.create_gcs_bucket.expiration_days
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
  bucket = local.create_gcs_bucket ? google_storage_bucket.atlas[0].name : var.bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.atlas_service_account_email}"
}

resource "time_sleep" "iam_propagation" {
  depends_on      = [google_storage_bucket_iam_member.atlas, google_storage_bucket.atlas]
  create_duration = "30s"
}

resource "mongodbatlas_cloud_backup_snapshot_export_bucket" "this" {
  project_id     = var.project_id
  cloud_provider = "GCP"
  bucket_name    = local.bucket_name
  role_id        = var.role_id

  depends_on = [time_sleep.iam_propagation, google_storage_bucket.atlas]
}
