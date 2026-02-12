locals {
  create_bucket = var.create_bucket.enabled
  default_name  = "atlas-backup-${var.project_id}${var.create_bucket.name_suffix}"
  resolved_name = var.create_bucket.name != "" ? var.create_bucket.name : local.default_name
  bucket_name   = local.create_bucket ? local.resolved_name : var.bucket_name
  bucket_url = local.create_bucket ? (
    google_storage_bucket.atlas[0].url
  ) : data.google_storage_bucket.user_provided[0].url
}

data "google_storage_bucket" "user_provided" {
  count = local.create_bucket ? 0 : 1
  name  = var.bucket_name
}

resource "google_storage_bucket" "atlas" {
  count                       = local.create_bucket ? 1 : 0
  name                        = local.resolved_name
  location                    = var.create_bucket.location
  storage_class               = var.create_bucket.storage_class
  force_destroy               = var.create_bucket.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels

  versioning {
    enabled = var.create_bucket.versioning_enabled
  }

  lifecycle {
    precondition {
      condition     = length(local.resolved_name) >= 3 && length(local.resolved_name) <= 63
      error_message = "Bucket name '${local.resolved_name}' (${length(local.resolved_name)} chars) must be 3-63 characters."
    }
  }
}

resource "google_storage_bucket_iam_member" "atlas" {
  bucket = local.bucket_name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.atlas_service_account_email}"
}

resource "mongodbatlas_cloud_backup_snapshot_export_bucket" "this" {
  project_id     = var.project_id
  cloud_provider = "GCP"
  bucket_name    = local.bucket_name
  role_id        = var.role_id

  depends_on = [google_storage_bucket_iam_member.atlas]
}
