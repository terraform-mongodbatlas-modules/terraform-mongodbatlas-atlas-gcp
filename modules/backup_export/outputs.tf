output "export_bucket_id" {
  description = "Atlas export bucket ID for backup schedule auto_export_enabled"
  value       = mongodbatlas_cloud_backup_snapshot_export_bucket.this.export_bucket_id
}

output "bucket_name" {
  description = "GCS bucket name"
  value       = local.bucket_name
}

output "bucket_location" {
  description = "GCS bucket location (region, dual-region, or multi-region)"
  value       = local.bucket_location
}

output "bucket_url" {
  description = "GCS bucket URL (gs://bucket-name)"
  value       = local.bucket_url
}
