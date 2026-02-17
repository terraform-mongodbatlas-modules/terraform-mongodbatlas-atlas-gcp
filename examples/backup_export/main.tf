module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  backup_export = {
    enabled = true
    create_bucket = {
      enabled       = true
      name          = var.bucket_name
      name_suffix   = var.bucket_name_suffix
      location      = var.gcp_region
      force_destroy = var.force_destroy
    }
  }

  gcp_tags = var.gcp_tags
}

# Alternative: user-provided bucket (uncomment and remove create_bucket above)
# module "atlas_gcp" {
#   source     = "../../"
#   project_id = var.project_id
#
#   backup_export = {
#     enabled     = true
#     bucket_name = "my-existing-bucket"
#   }
#
#   gcp_tags = var.gcp_tags
# }

# backup export configuration and GCS bucket details
output "backup_export" {
  value = module.atlas_gcp.backup_export
}

# export_bucket_id -- pass to cluster module's backup schedule export { export_bucket_id = ... }
output "export_bucket_id" {
  value = module.atlas_gcp.export_bucket_id
}
