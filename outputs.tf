output "role_id" {
  description = "Atlas role ID for reuse with other Atlas-GCP features"
  value       = local.role_id
}

output "encryption_at_rest_provider" {
  description = "Value for cluster's encryption_at_rest_provider attribute"
  value       = var.encryption.enabled ? "GCP" : "NONE"
}

output "encryption" {
  description = "Encryption at rest status and KMS configuration"
  value = var.encryption.enabled ? {
    valid                   = module.encryption[0].valid
    key_version_resource_id = module.encryption[0].key_version_resource_id
    crypto_key_id           = module.encryption[0].crypto_key_id
    key_ring_name           = module.encryption[0].key_ring_name
    crypto_key_name         = module.encryption[0].crypto_key_name
    kms_location            = module.encryption[0].kms_location
  } : null
}

output "resource_ids" {
  description = "GCP resource IDs for data source lookups"
  value = {
    # Cloud Provider Access
    role_id                       = local.role_id
    service_account_for_atlas     = local.service_account_for_atlas
    encryption_role_id            = local.encryption_role_id
    encryption_service_account    = local.encryption_service_account
    backup_export_role_id         = local.backup_export_role_id
    backup_export_service_account = local.backup_export_service_account

    # Encryption
    crypto_key_id = try(module.encryption[0].crypto_key_id, null)
    key_ring_id   = try(module.encryption[0].key_ring_id, null)

    # Backup Export
    bucket_name = try(module.backup_export[0].bucket_name, null)
    bucket_url  = try(module.backup_export[0].bucket_url, null)
  }
}

output "privatelink" {
  description = "PrivateLink status per endpoint key (both module-managed and BYOE)"
  value = {
    for k, pl in module.privatelink : k => {
      region                      = local.privatelink_module_calls[k].region
      atlas_private_link_id       = pl.atlas_private_link_id
      atlas_endpoint_service_name = pl.atlas_endpoint_service_name
      gcp_endpoint_ip             = pl.gcp_endpoint_ip
      status                      = pl.status
      error_message               = pl.error_message
      gcp_endpoint_status         = pl.gcp_endpoint_status
      gcp_forwarding_rule_id      = pl.gcp_forwarding_rule_id
      gcp_project_id              = pl.gcp_project_id
    }
  }
}

output "privatelink_service_info" {
  description = "Atlas PrivateLink service info per endpoint key (for BYOE - create your GCP PSC endpoint using these values)"
  value = {
    for k, ep in mongodbatlas_privatelink_endpoint.this : k => {
      region                      = local.privatelink_endpoints_all[k].region
      atlas_private_link_id       = ep.private_link_id
      atlas_endpoint_service_name = ep.endpoint_service_name
      service_attachment_names    = ep.service_attachment_names
    }
  }
}

output "regional_mode_enabled" {
  description = "Whether private endpoint regional mode is enabled (auto-enabled for multi-region)"
  value       = local.enable_regional_mode
}

output "export_bucket_id" {
  description = "Export bucket ID for backup schedule auto_export_enabled"
  value       = var.backup_export.enabled ? module.backup_export[0].export_bucket_id : null
}

output "backup_export" {
  description = "Backup export configuration and GCS bucket details"
  value = var.backup_export.enabled ? {
    export_bucket_id = module.backup_export[0].export_bucket_id
    bucket_name      = module.backup_export[0].bucket_name
    bucket_location  = module.backup_export[0].bucket_location
    bucket_url       = module.backup_export[0].bucket_url
  } : null
}
