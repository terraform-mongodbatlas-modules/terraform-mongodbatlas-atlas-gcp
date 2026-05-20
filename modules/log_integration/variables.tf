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

variable "skip_iam_bindings" {
  type        = bool
  default     = false
  description = "Skip google_storage_bucket_iam_member when IAM is pre-granted externally"
}

variable "bucket_name" {
  type        = string
  default     = null
  description = "User-provided GCS bucket name"

  validation {
    condition     = var.create_gcs_bucket.enabled || var.bucket_name != null
    error_message = "bucket_name is required when create_gcs_bucket.enabled = false."
  }
}

variable "create_gcs_bucket" {
  type = object({
    enabled                     = optional(bool, false)
    name                        = optional(string, "")
    name_suffix                 = optional(string, "")
    location                    = optional(string, "")
    force_destroy               = optional(bool, false)
    storage_class               = optional(string, "STANDARD")
    versioning_enabled          = optional(bool, true)
    uniform_bucket_level_access = optional(bool, true)
    public_access_prevention    = optional(string, "enforced")
    expiration_days             = optional(number)
  })
  default     = {}
  nullable    = false
  description = "Module-managed GCS bucket configuration. When name is omitted, defaults to atlas-logs-{project_id}{name_suffix}."
}

variable "integrations" {
  type = list(object({
    log_types   = list(string)
    prefix_path = optional(string, "")
    bucket_name = optional(string)
  }))
  description = "Log integration entries; each creates one mongodbatlas_log_integration"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels for GCP resources"
}
