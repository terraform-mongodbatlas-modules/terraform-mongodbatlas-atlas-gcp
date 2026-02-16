resource "google_kms_key_ring" "atlas" {
  name     = var.key_ring_name
  location = var.gcp_region
  project  = var.gcp_project_id
}

resource "google_kms_crypto_key" "atlas" {
  name     = "atlas-encryption-key"
  key_ring = google_kms_key_ring.atlas.id
  purpose  = "ENCRYPT_DECRYPT"
}

module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  encryption = {
    enabled                 = true
    key_version_resource_id = google_kms_crypto_key.atlas.primary[0].name
  }

  gcp_tags = var.gcp_tags
}

output "encryption" {
  value = module.atlas_gcp.encryption
}

output "resource_ids" {
  description = "All resource IDs created by the module"
  value       = module.atlas_gcp.resource_ids
}
