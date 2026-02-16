module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  privatelink_endpoints = [
    { region = "us-east4", subnetwork = var.subnetwork_us_east4 },
    { region = "us-west1", subnetwork = var.subnetwork_us_west1 },
  ]

  gcp_tags = var.gcp_tags
}

output "privatelink" {
  description = "PrivateLink status per endpoint key"
  value       = module.atlas_gcp.privatelink
}

output "regional_mode_enabled" {
  description = "Whether private endpoint regional mode is enabled"
  value       = module.atlas_gcp.regional_mode_enabled
}

output "privatelink_service_info" {
  description = "Atlas PrivateLink service info for BYOE pattern"
  value       = module.atlas_gcp.privatelink_service_info
}
