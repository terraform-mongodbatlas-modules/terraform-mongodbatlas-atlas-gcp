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
  description = "Default GCP region for provider"
  default     = "us-east4"
}

variable "subnetwork_us_east4" {
  type        = string
  description = "Subnetwork self_link in us-east4 for PSC endpoint"
}

variable "subnetwork_us_west1" {
  type        = string
  description = "Subnetwork self_link in us-west1 for PSC endpoint"
}

variable "gcp_tags" {
  type        = map(string)
  description = "Labels to apply to GCP resources"
  default     = {}
}
