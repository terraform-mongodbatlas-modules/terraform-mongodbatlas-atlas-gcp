locals {
  create_gcs_bucket = var.create_gcs_bucket.enabled
  default_name      = "atlas-logs-${var.project_id}${var.create_gcs_bucket.name_suffix}"
  resolved_name     = var.create_gcs_bucket.name != "" ? var.create_gcs_bucket.name : local.default_name
  bucket_name       = local.create_gcs_bucket ? local.resolved_name : var.bucket_name
  bucket_url        = local.create_gcs_bucket ? google_storage_bucket.atlas[0].url : data.google_storage_bucket.user_provided[0].url

  byo_bucket_names = distinct(compact([for i in var.integrations : i.bucket_name]))
  # Static for_each keys; bucket names in values may be unknown until apply, so the default name using project_id might not be available yet.
  iam_bucket_targets = merge(
    { default = local.bucket_name },
    { for name in local.byo_bucket_names : name => name },
  )
}

data "google_storage_bucket" "user_provided" {
  count = local.create_gcs_bucket ? 0 : 1
  name  = var.bucket_name
}

data "google_storage_bucket" "integration_byo" {
  for_each = toset(local.byo_bucket_names)
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
    for_each = local.create_gcs_bucket && var.create_gcs_bucket.expiration_days > 0 ? [1] : []

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
  for_each = var.skip_iam_bindings ? {} : local.iam_bucket_targets

  # Reference the managed bucket resource so IAM waits for creation (each.value alone has no dependency edge).
  bucket = each.key == "default" && local.create_gcs_bucket ? google_storage_bucket.atlas[0].name : each.value
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.atlas_service_account_email}"

  depends_on = [data.google_storage_bucket.integration_byo]
}

resource "time_sleep" "iam_propagation" {
  depends_on = [
    google_storage_bucket_iam_member.atlas,
    google_storage_bucket.atlas,
    data.google_storage_bucket.integration_byo,
    data.google_storage_bucket.user_provided,
  ]
  create_duration = "30s"
}

resource "mongodbatlas_log_integration" "this" {
  count = length(var.integrations)

  project_id  = var.project_id
  type        = "GCS_LOG_EXPORT"
  role_id     = var.role_id
  log_types   = var.integrations[count.index].log_types
  prefix_path = trimsuffix(var.integrations[count.index].prefix_path, "/")
  bucket_name = coalesce(var.integrations[count.index].bucket_name, local.bucket_name)

  depends_on = [time_sleep.iam_propagation]
}
