output "atlas_private_link_id" {
  description = "Atlas PrivateLink connection ID"
  value       = var.private_link_id
}

output "atlas_endpoint_service_name" {
  description = "Atlas endpoint service name (forwarding rule name)"
  value       = mongodbatlas_privatelink_endpoint_service.this.endpoint_service_id
}

output "gcp_endpoint_ip" {
  description = "IP address of the PSC endpoint"
  value       = local.endpoint_ip
}

output "status" {
  description = "PrivateLink connection status"
  value       = data.mongodbatlas_privatelink_endpoint_service.this.gcp_status
}

output "error_message" {
  description = "Error message if connection failed"
  value       = data.mongodbatlas_privatelink_endpoint_service.this.error_message
}

output "gcp_endpoint_status" {
  description = "Port-mapped endpoint status (distinct from overall gcp_status)"
  value       = data.mongodbatlas_privatelink_endpoint_service.this.gcp_endpoint_status
}

output "gcp_forwarding_rule_id" {
  description = "GCP forwarding rule ID (null for BYOE)"
  value       = local.module_managed ? google_compute_forwarding_rule.atlas[0].id : null
}
