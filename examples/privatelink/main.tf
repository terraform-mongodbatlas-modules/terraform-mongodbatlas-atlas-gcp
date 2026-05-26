module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  privatelink_endpoints     = var.privatelink_endpoints
  privatelink_regional_mode = var.privatelink_regional_mode

  gcp_tags = var.gcp_tags
}

output "privatelink" {
  description = "PrivateLink status per endpoint key"
  value       = module.atlas_gcp.privatelink
}
