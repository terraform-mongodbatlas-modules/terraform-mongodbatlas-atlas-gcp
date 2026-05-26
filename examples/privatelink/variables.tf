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
    region          = string
    subnetwork      = string
    labels          = optional(map(string), {})
    name_prefix     = optional(string)
    all_region_mode = optional(bool)
  }))
  description = "Module-managed PrivateLink endpoints via PSC"
}

variable "privatelink_regional_mode" {
  type        = string
  description = "Atlas project regional mode for sharded clusters (auto or disabled)"
  default     = "disabled"
}

variable "gcp_tags" {
  type        = map(string)
  description = "Labels to apply to GCP resources"
  default     = {}
}
