output "role_id" {
  description = "Atlas Cloud Provider Access role ID"
  value       = local.role_id
}

output "encryption_at_rest_provider" {
  description = "Value for cluster's encryption_at_rest_provider attribute"
  value       = var.encryption.enabled ? "GCP" : "NONE"
}

output "encryption" {
  description = "Encryption at rest status and configuration"
  value = var.encryption.enabled ? {
    valid                   = module.encryption[0].valid
    key_version_resource_id = module.encryption[0].key_version_resource_id
    crypto_key_id           = module.encryption[0].crypto_key_id
  } : null
}

output "resource_ids" {
  description = "All resource IDs for data source lookups"
  value = {
    role_id                       = local.role_id
    service_account_for_atlas     = local.service_account_for_atlas
    encryption_role_id            = local.encryption_role_id
    encryption_service_account    = local.encryption_service_account
    backup_export_role_id         = local.backup_export_role_id
    backup_export_service_account = local.backup_export_service_account
    crypto_key_id                 = var.encryption.enabled ? module.encryption[0].crypto_key_id : null
    key_ring_id                   = var.encryption.enabled ? module.encryption[0].key_ring_id : null
    bucket_name                   = null # TODO(CLOUDP-379594): wire to backup_export module
    bucket_url                    = null # TODO(CLOUDP-379594): wire to backup_export module
  }
}

output "privatelink" {
  description = "PrivateLink status per endpoint key"
  value       = {} # TODO: wire when privatelink submodule is built
}

output "privatelink_service_info" {
  description = "Atlas PrivateLink service info for BYOE pattern"
  value = {
    for k, ep in mongodbatlas_privatelink_endpoint.this : k => {
      private_link_id          = ep.private_link_id
      endpoint_service_name    = ep.endpoint_service_name
      service_attachment_names = ep.service_attachment_names
    }
  }
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
