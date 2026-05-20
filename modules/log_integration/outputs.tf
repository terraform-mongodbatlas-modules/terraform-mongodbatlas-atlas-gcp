locals {
  bucket_url = local.create_gcs_bucket ? (
    google_storage_bucket.atlas[0].url
  ) : data.google_storage_bucket.byo[var.bucket_name].url
}

output "bucket_name" {
  description = "Default GCS bucket name (module-managed or root BYO)"
  value       = local.default_bucket_name
}

output "bucket_url" {
  description = "Default GCS bucket URL (gs://bucket-name)"
  value       = local.bucket_url
}

output "integration_ids" {
  description = "Atlas log integration IDs"
  value       = mongodbatlas_log_integration.this[*].integration_id
}
