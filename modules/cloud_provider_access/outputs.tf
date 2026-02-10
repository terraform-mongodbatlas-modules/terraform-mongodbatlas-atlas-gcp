output "role_id" {
  description = "Atlas Cloud Provider Access role ID"
  value       = mongodbatlas_cloud_provider_access_authorization.this.role_id
}

output "service_account_for_atlas" {
  description = "GCP service account created by Atlas for IAM bindings"
  value       = mongodbatlas_cloud_provider_access_authorization.this.gcp[0].service_account_for_atlas
}
