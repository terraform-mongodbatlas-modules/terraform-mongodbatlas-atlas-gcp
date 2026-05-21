module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  log_integration = {
    enabled = true
    create_gcs_bucket = {
      enabled       = true
      name          = var.bucket_name
      name_suffix   = var.bucket_name_suffix
      location      = var.gcp_region
      force_destroy = var.force_destroy
    }
    integrations = [
      {
        log_types   = ["MONGOD", "MONGOS"]
        prefix_path = "logs"
      },
      {
        log_types   = ["MONGOD_AUDIT", "MONGOS_AUDIT"]
        prefix_path = "audit"
      },
    ]
  }

  gcp_tags = var.gcp_tags
}

output "log_integration" {
  value = module.atlas_gcp.log_integration
}

output "integration_ids" {
  value = module.atlas_gcp.log_integration.integration_ids
}
