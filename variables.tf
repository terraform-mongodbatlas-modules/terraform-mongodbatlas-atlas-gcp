variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "cloud_provider_access" {
  type = object({
    create = optional(bool, true)
    existing = optional(object({
      role_id                   = string
      service_account_for_atlas = string
    }))
  })
  default     = {}
  description = <<-EOT
    Cloud provider access configuration for Atlas-GCP integration.
    - `create = true` (default): Creates a shared Atlas service account and authorization
    - `create = false`: Use existing CPA via `existing.role_id` and `existing.service_account_for_atlas`
  EOT

  validation {
    condition     = var.cloud_provider_access.create || var.cloud_provider_access.existing != null
    error_message = "When cloud_provider_access.create = false, existing.role_id and existing.service_account_for_atlas are required."
  }

  validation {
    condition     = !var.cloud_provider_access.create || var.cloud_provider_access.existing == null
    error_message = "cloud_provider_access.create and cloud_provider_access.existing are mutually exclusive: use either create = true (without existing) or create = false (with existing)."
  }
}

variable "encryption" {
  type = object({
    enabled                 = optional(bool, false)
    key_version_resource_id = optional(string)
    create_kms_key = optional(object({
      enabled         = optional(bool, false)
      key_ring_name   = optional(string)
      crypto_key_name = optional(string)
      location        = optional(string, "")
      rotation_period = optional(string)
    }), {})
    dedicated_role_enabled = optional(bool, false)
  })
  default     = {}
  description = <<-EOT
    Encryption at rest configuration with Google Cloud KMS.

    Provide EITHER:
    - `key_version_resource_id` (user-provided KMS key version)
    - `create_kms_key.enabled = true` (module-managed Key Ring + Crypto Key)

    When `key_ring_name` is omitted, defaults to `atlas-{project_id}-keyring` to avoid
    collisions across Atlas projects. `crypto_key_name` defaults to `atlas-encryption-key`.
    Key rings are permanent in GCP -- choose stable names.

    `location` accepts GCP locations (`us-east4`) or Atlas region names (`US_EAST_4`).
    Multi-regional locations (`us`, `europe`, `asia`) are also valid.

    `rotation_period` controls GCP automatic key version rotation.
    Format: seconds as string, e.g., "7776000s" (90 days). Should be > 86400s (1 day).
    When omitted, no automatic rotation occurs. Atlas recommends 90-day rotation and
    creates an alert at that cadence. Each rotation causes a plan diff on
    key_version_resource_id on the next terraform apply. Old key versions remain
    enabled -- no data re-encryption is needed.

    `dedicated_role_enabled = true` creates a dedicated Atlas service account for encryption.
  EOT

  validation {
    condition     = !(var.encryption.key_version_resource_id != null && var.encryption.create_kms_key.enabled)
    error_message = "Cannot use both key_version_resource_id (user-provided) and create_kms_key.enabled = true (module-managed)."
  }

  validation {
    condition     = !var.encryption.enabled || (var.encryption.key_version_resource_id != null || var.encryption.create_kms_key.enabled)
    error_message = "encryption.enabled = true requires key_version_resource_id OR create_kms_key.enabled = true."
  }

  validation {
    condition     = var.encryption.enabled || (var.encryption.key_version_resource_id == null && !var.encryption.create_kms_key.enabled)
    error_message = "encryption.key_version_resource_id and create_kms_key.enabled can only be set when encryption.enabled = true."
  }

  validation {
    condition     = !var.encryption.create_kms_key.enabled || var.encryption.create_kms_key.location != ""
    error_message = "create_kms_key.location is required when create_kms_key.enabled = true."
  }

  validation {
    condition = var.encryption.key_version_resource_id == null ? true : can(
      regex("^projects/.+/locations/.+/keyRings/.+/cryptoKeys/.+/cryptoKeyVersions/.+$", var.encryption.key_version_resource_id)
    )
    error_message = "key_version_resource_id must be a full GCP resource path: projects/{project}/locations/{location}/keyRings/{ring}/cryptoKeys/{key}/cryptoKeyVersions/{version}"
  }
}

variable "privatelink_endpoints" {
  type = list(object({
    region     = string
    subnetwork = string
    labels     = optional(map(string), {})
  }))
  default     = []
  description = "Multi-region PrivateLink endpoints via PSC. Region accepts us-east4 or US_EAST_4 format. All regions must be UNIQUE."

  validation {
    condition     = length(var.privatelink_endpoints) == length(distinct([for ep in var.privatelink_endpoints : ep.region]))
    error_message = "All regions in privatelink_endpoints must be unique. Use privatelink_endpoints_single_region for multiple endpoints in the same region."
  }
}

variable "privatelink_endpoints_single_region" {
  type = list(object({
    region     = string
    subnetwork = string
    labels     = optional(map(string), {})
  }))
  default     = []
  description = <<-EOT
    Single-region multi-endpoint pattern. All regions must MATCH.
    Use when multiple VPCs in the same region need PSC connectivity to Atlas.
  EOT

  validation {
    condition     = length(var.privatelink_endpoints_single_region) == 0 || length(distinct([for ep in var.privatelink_endpoints_single_region : ep.region])) == 1
    error_message = "All regions in privatelink_endpoints_single_region must match (same region)."
  }

  validation {
    condition     = length(var.privatelink_endpoints_single_region) == 0 || length(var.privatelink_endpoints) == 0
    error_message = "Cannot use both privatelink_endpoints and privatelink_endpoints_single_region."
  }
}

variable "privatelink_byoe_regions" {
  type        = map(string)
  default     = {}
  description = "BYOE Phase 1: Key is user identifier, value is GCP region (us-east4 or US_EAST_4)."

  validation {
    condition     = length(setintersection(values(var.privatelink_byoe_regions), [for ep in var.privatelink_endpoints : ep.region])) == 0
    error_message = "Regions in privatelink_byoe_regions must not overlap with regions in privatelink_endpoints."
  }
}

variable "privatelink_byoe" {
  type = map(object({
    ip_address           = string
    forwarding_rule_name = string
  }))
  default     = {}
  description = "BYOE Phase 2: Forwarding rule details. Key must exist in privatelink_byoe_regions."

  validation {
    condition     = alltrue([for k in keys(var.privatelink_byoe) : contains(keys(var.privatelink_byoe_regions), k)])
    error_message = "All keys in privatelink_byoe must exist in privatelink_byoe_regions."
  }
}

variable "backup_export" {
  type = object({
    enabled     = optional(bool, false)
    bucket_name = optional(string)
    create_bucket = optional(object({
      enabled            = optional(bool, false)
      name               = optional(string, "")
      location           = optional(string, "")
      force_destroy      = optional(bool, false)
      storage_class      = optional(string, "STANDARD")
      versioning_enabled = optional(bool, true)
    }), {})
    dedicated_role_enabled = optional(bool, false)
  })
  default     = {}
  description = <<-EOT
    Backup snapshot export to GCS configuration.

    Provide EITHER:
    - `bucket_name` (user-provided GCS bucket)
    - `create_bucket.enabled = true` (module-managed GCS bucket)

    `dedicated_role_enabled = true` creates a dedicated Atlas service account for backup export.
  EOT

  validation {
    condition     = !(var.backup_export.bucket_name != null && var.backup_export.create_bucket.enabled)
    error_message = "Cannot use both bucket_name (user-provided) and create_bucket.enabled = true (module-managed)."
  }

  validation {
    condition     = !var.backup_export.enabled || (var.backup_export.bucket_name != null || var.backup_export.create_bucket.enabled)
    error_message = "backup_export.enabled = true requires bucket_name OR create_bucket.enabled = true."
  }

  validation {
    condition     = var.backup_export.enabled || (var.backup_export.bucket_name == null && !var.backup_export.create_bucket.enabled)
    error_message = "bucket_name and create_bucket.enabled may only be set when backup_export.enabled = true."
  }

  validation {
    condition = !var.backup_export.create_bucket.enabled || (
      var.backup_export.create_bucket.name != "" &&
      var.backup_export.create_bucket.location != ""
    )
    error_message = "create_bucket requires name and location when enabled."
  }
}

variable "gcp_tags" {
  type        = map(string)
  default     = {}
  description = "Labels to apply to all GCP resources created by this module."
}
