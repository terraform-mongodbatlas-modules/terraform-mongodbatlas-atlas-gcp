variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID for the google provider"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for bucket location and provider"
  default     = "us-east4"
}

variable "bucket_name" {
  type        = string
  description = "Exact GCS bucket name (mutually exclusive with bucket_name_suffix)"
  default     = null
}

variable "bucket_name_suffix" {
  type        = string
  description = "Appended to default atlas-backup-{project_id} (include separator, e.g. \"-dev\")"
  default     = ""
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket deletion when not empty"
  default     = false
}

variable "gcp_tags" {
  type        = map(string)
  description = "Labels to apply to GCP resources"
  default     = {}
}
