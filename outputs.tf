output "role_id" {
  description = "Atlas Cloud Provider Access role ID (echoes existing config until resource wiring in CLOUDP-379585)"
  value       = local.role_id
}

output "encryption_at_rest_provider" {
  description = "Value for cluster's encryption_at_rest_provider attribute"
  value       = var.encryption.enabled ? "GCP" : "NONE"
}

output "encryption" {
  description = "Encryption at rest status and configuration"
  value       = null # TODO(CLOUDP-379590): wire to encryption module
}

output "resource_ids" {
  description = "All resource IDs for data source lookups"
  value = {
    role_id                   = local.role_id
    service_account_for_atlas = local.service_account_for_atlas
    crypto_key_id             = null # TODO(CLOUDP-379590): wire to encryption module
    key_ring_id               = null # TODO(CLOUDP-379590): wire to encryption module
    bucket_name               = null # TODO(CLOUDP-379594): wire to backup_export module
    bucket_url                = null # TODO(CLOUDP-379594): wire to backup_export module
  }
}

output "privatelink" {
  description = "PrivateLink status per endpoint key"
  value       = {} # TODO(CLOUDP-379585): wire to privatelink module
}

output "privatelink_service_info" {
  description = "Atlas PrivateLink service info for BYOE pattern"
  value       = {} # TODO(CLOUDP-379585): wire to mongodbatlas_privatelink_endpoint
}

output "regional_mode_enabled" {
  description = "Whether private endpoint regional mode is enabled"
  value       = local.enable_regional_mode
}

output "export_bucket_id" {
  description = "Export bucket ID for backup schedule auto_export_enabled"
  value       = null # TODO(CLOUDP-379594): wire to backup_export module
}

output "backup_export" {
  description = "Backup export configuration"
  value       = null # TODO(CLOUDP-379594): wire to backup_export module
}
