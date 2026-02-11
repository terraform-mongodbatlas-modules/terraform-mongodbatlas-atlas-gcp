variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "role_id" {
  type        = string
  description = "Atlas cloud provider access role ID"
}

variable "atlas_service_account_email" {
  type        = string
  description = "Atlas-managed GCP service account email for IAM bindings"
}

variable "key_version_resource_id" {
  type        = string
  default     = null
  description = "User-provided KMS crypto key version resource ID"
}

variable "create_kms_key" {
  type = object({
    enabled         = optional(bool, false)
    key_ring_name   = optional(string, "atlas-keyring")
    crypto_key_name = optional(string, "atlas-encryption-key")
    location        = optional(string, "")
    rotation_period = optional(string)
  })
  default     = {}
  nullable    = false
  description = "Module-managed KMS key configuration"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels for GCP resources"
}
