output "valid" {
  description = "Whether the encryption configuration is valid"
  value       = mongodbatlas_encryption_at_rest.this.google_cloud_kms_config[0].valid
}

output "encryption_at_rest_provider" {
  description = "Value for cluster's encryption_at_rest_provider attribute"
  value       = "GCP"
}

output "project_id" {
  description = "Project ID for downstream dependencies"
  value       = var.project_id
}

output "key_version_resource_id" {
  description = "KMS crypto key version resource ID (user-provided or module-created)"
  value       = local.key_version_resource_id
}

output "crypto_key_id" {
  description = "KMS crypto key ID for IAM reference"
  value       = local.crypto_key_id
}

output "key_ring_id" {
  description = "KMS key ring ID (null if user-provided key)"
  value       = local.create_kms_key ? google_kms_key_ring.atlas[0].id : null
}

output "key_ring_name" {
  description = "Resolved key ring name (auto-generated or user-provided)"
  value       = local.key_ring_name
}

output "crypto_key_name" {
  description = "Resolved crypto key name (auto-generated or user-provided)"
  value       = local.crypto_key_name
}

output "kms_location" {
  description = "GCP KMS location (normalized to GCP format)"
  value       = local.kms_location
}

output "enabled_for_search_nodes" {
  description = "Whether encryption at rest is enabled for search nodes"
  value       = mongodbatlas_encryption_at_rest.this.enabled_for_search_nodes
}
