variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where KMS resources are created"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for KMS Key Ring location"
  default     = "us-east4"
}

variable "key_ring_name" {
  type        = string
  description = "Name of the KMS Key Ring"
  default     = "atlas-encryption-keyring"
}

variable "gcp_tags" {
  type        = map(string)
  description = "Labels to apply to GCP resources"
  default     = {}
}
