module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  skip_iam_bindings = true

  cloud_provider_access = {
    create = false
    existing = {
      role_id                   = var.atlas_role_id
      service_account_for_atlas = var.atlas_service_account_email
    }
  }

  encryption = {
    enabled                 = true
    key_version_resource_id = var.kms_key_version_resource_id
  }

  backup_export = {
    enabled     = true
    bucket_name = var.backup_bucket_name
  }

  log_integration = {
    enabled     = true
    bucket_name = var.log_bucket_name
    integrations = [
      { log_types = ["MONGOD"], prefix_path = "operational/" },
      { log_types = ["MONGOD_AUDIT"], prefix_path = "audit/" },
    ]
  }
}

output "encryption_at_rest_provider" {
  value = module.atlas_gcp.encryption_at_rest_provider
}

output "encryption" {
  value = module.atlas_gcp.encryption
}

output "backup_export" {
  value = module.atlas_gcp.backup_export
}

output "export_bucket_id" {
  value = module.atlas_gcp.export_bucket_id
}

output "log_integration" {
  value = module.atlas_gcp.log_integration
}
