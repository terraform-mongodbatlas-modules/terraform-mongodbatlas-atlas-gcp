variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for PSC endpoint"
  default     = "us-east4"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork self_link for PSC endpoint IP allocation"
}

variable "gcp_tags" {
  type        = map(string)
  description = "Labels to apply to GCP resources"
  default     = {}
}
