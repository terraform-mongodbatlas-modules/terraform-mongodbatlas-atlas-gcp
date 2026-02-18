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

  validation {
    condition     = var.create_kms_key.enabled || var.key_version_resource_id != null
    error_message = "key_version_resource_id is required when create_kms_key.enabled = false."
  }

  validation {
    condition     = !var.create_kms_key.enabled || var.key_version_resource_id == null
    error_message = "key_version_resource_id must not be set when create_kms_key.enabled = true."
  }
}

variable "create_kms_key" {
  type = object({
    enabled         = optional(bool, false)
    key_ring_name   = optional(string)
    crypto_key_name = optional(string)
    location        = optional(string, "")
    rotation_period = optional(string)
  })
  default     = {}
  nullable    = false
  description = <<-EOT
    Module-managed KMS key configuration.

    `rotation_period` controls GCP automatic key version rotation.
    Format: seconds as string, e.g., "7776000s" (90 days). Should be > 86400s (1 day).
    When omitted, no automatic rotation occurs.
    Atlas recommends rotating CMKs every 90 days and creates an alert at that cadence.
    Each rotation causes a plan diff on key_version_resource_id on the next terraform apply.
    Old key versions remain enabled and functional -- no data re-encryption is needed.
  EOT
}

variable "enabled_for_search_nodes" {
  type        = bool
  default     = true
  description = "Enable Encryption at Rest for Dedicated Search Nodes"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels for GCP resources"
}
