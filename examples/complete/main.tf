module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  encryption = {
    enabled = true
    create_kms_key = {
      enabled         = true
      key_ring_name   = var.key_ring_name
      crypto_key_name = "atlas-encryption-key"
      location        = var.gcp_region
    }
  }

  backup_export = {
    enabled = true
    create_bucket = {
      enabled       = true
      name_suffix   = var.bucket_name_suffix
      location      = var.gcp_region
      force_destroy = var.force_destroy
    }
  }

  privatelink_endpoints = var.privatelink_endpoints

  gcp_tags = var.gcp_tags
}

output "encryption" {
  value = module.atlas_gcp.encryption
}

output "encryption_at_rest_provider" {
  value = module.atlas_gcp.encryption_at_rest_provider
}

output "backup_export" {
  value = module.atlas_gcp.backup_export
}

output "export_bucket_id" {
  value = module.atlas_gcp.export_bucket_id
}

output "privatelink" {
  value = module.atlas_gcp.privatelink
}

output "resource_ids" {
  description = "All resource IDs created by the module"
  value       = module.atlas_gcp.resource_ids
}
