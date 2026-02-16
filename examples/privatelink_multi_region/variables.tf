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

variable "privatelink_endpoints" {
  type = list(object({
    region     = string
    subnetwork = string
    labels     = optional(map(string), {})
  }))
  description = "Multi-region PrivateLink endpoints via PSC. Region accepts us-east4 or US_EAST_4 format. All regions must be UNIQUE."
}

variable "gcp_tags" {
  type        = map(string)
  description = "Labels to apply to GCP resources"
  default     = {}
}
