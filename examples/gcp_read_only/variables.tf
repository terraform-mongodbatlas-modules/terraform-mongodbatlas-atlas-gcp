variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID for the google provider (read access for module data sources)"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for the google provider"
  default     = "us-east4"
}

variable "atlas_role_id" {
  type        = string
  description = "Existing Atlas cloud provider access role ID"
}

variable "atlas_service_account_email" {
  type        = string
  description = "Existing Atlas-managed GCP service account email"
}

variable "kms_key_version_resource_id" {
  type        = string
  description = "Full GCP resource path for the BYO KMS crypto key version"
}

variable "backup_bucket_name" {
  type        = string
  description = "GCS bucket name for backup export"
}

variable "log_bucket_name" {
  type        = string
  description = "GCS bucket name for log integration"
}
