variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP region (e.g., us-east4)"
}

variable "private_link_id" {
  type        = string
  description = "Atlas private link ID from mongodbatlas_privatelink_endpoint"
}

variable "service_attachment_name" {
  type        = string
  description = "First service attachment name (service_attachment_names[0]). Port-mapped architecture only needs the first."
}

variable "subnetwork" {
  type        = string
  default     = null
  description = "Subnetwork self_link for module-managed PSC endpoint. Null for BYOE."
}

variable "byo" {
  type = object({
    ip_address           = string
    forwarding_rule_name = string
  })
  default     = null
  description = "BYOE forwarding rule details. Null for module-managed."

  validation {
    condition     = (var.subnetwork != null) != (var.byo != null)
    error_message = "Exactly one of subnetwork (module-managed) or byo (BYOE) must be provided."
  }
}

variable "name_prefix" {
  type        = string
  default     = "atlas-psc"
  description = "Prefix for GCP resource names (address and forwarding rule)."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels to apply to GCP resources."
}
