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

    `key_ring_name` sets the name for the GCP KMS key ring. When omitted, defaults to
    `atlas-{project_id}-keyring` to avoid collisions across Atlas projects sharing the
    same GCP project and location. Key rings are permanent in GCP -- choose stable names.
    GCP allows 1-63 characters (`[a-zA-Z][a-zA-Z0-9_-]*`); the auto-generated name is
    38 characters (well within the limit).

    `crypto_key_name` sets the name for the GCP KMS crypto key within the key ring.
    When omitted, defaults to `atlas-encryption-key`. No project ID prefix needed since
    the key is already scoped within the key ring.

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
  description = <<-EOT
    Multi-region PrivateLink endpoints via Private Service Connect (PSC).

    Each entry creates one GCP forwarding rule + address pair. PSC uses a port-mapped
    architecture: one forwarding rule per region, PSC handles port-to-node routing internally.

    - `region` accepts both GCP format (`us-east4`) and Atlas format (`US_EAST_4`).
      All regions must be unique -- use `privatelink_endpoints_single_region` for
      multiple VPCs in the same region.
    - `subnetwork` is a self_link (e.g., `google_compute_subnetwork.this.self_link`).
      The VPC network is derived from the subnetwork -- no separate `network` input needed.
    - `labels` are applied to the GCP forwarding rule and compute address resources.
  EOT

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
    Single-region PrivateLink endpoints for multiple VPCs in the same GCP region.

    Use when two or more VPCs in the same region each need PSC connectivity to the
    same Atlas project. Uses list index as the `for_each` key (not region), since
    the region is identical for all entries.

    Same object shape as `privatelink_endpoints`. Mutually exclusive with
    `privatelink_endpoints`.
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
  description = <<-EOT
    BYOE (Bring Your Own Endpoint) Phase 1: declare regions for Atlas endpoint service creation.

    Key is a user-chosen identifier (not necessarily a region name). Value is a GCP
    region (`us-east4` or `US_EAST_4`). Atlas creates the endpoint service and returns
    `service_attachment_names` via the `privatelink_service_info` output.

    Regions must not overlap with `privatelink_endpoints` regions.
    Phase 2 (`privatelink_byoe`) completes the connection.
  EOT

  validation {
    condition     = length(setintersection(values(var.privatelink_byoe_regions), [for ep in var.privatelink_endpoints : ep.region])) == 0
    error_message = "Regions in privatelink_byoe_regions must not overlap with regions in privatelink_endpoints."
  }
}

variable "privatelink_byoe" {
  type = map(object({
    ip_address           = string
    forwarding_rule_name = string
    gcp_project_id       = optional(string, null)
  }))
  default     = {}
  description = <<-EOT
    BYOE (Bring Your Own Endpoint) Phase 2: complete the PSC connection.

    After Phase 1 returns `service_attachment_names`, create your own
    `google_compute_address` + `google_compute_forwarding_rule` targeting
    `service_attachment_names[0]`, then pass the details here.

    - `ip_address` is the internal IP of your `google_compute_address`.
    - `forwarding_rule_name` is the GCP resource name of your `google_compute_forwarding_rule`.
    - `gcp_project_id` is used when the forwarding rule lives in a different GCP project than the provider default.
    - Key must exist in `privatelink_byoe_regions`.

    Both phases can run in a single `terraform apply` (see the `privatelink_byoe` example).
  EOT

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
      enabled                     = optional(bool, false)
      name                        = optional(string, "")
      name_suffix                 = optional(string, "")
      location                    = optional(string, "")
      force_destroy               = optional(bool, false)
      storage_class               = optional(string, "STANDARD")
      versioning_enabled          = optional(bool, true)
      uniform_bucket_level_access = optional(bool, true)
      public_access_prevention    = optional(string, "enforced")
    }), {})
    dedicated_role_enabled = optional(bool, false)
  })
  default     = {}
  description = <<-EOT
    Backup snapshot export to GCS configuration.

    Provide EITHER:
    - `bucket_name` (user-provided GCS bucket)
    - `create_bucket.enabled = true` (module-managed GCS bucket)

    **Bucket Naming:**
    - `name` accepts a string to set an explicit bucket name (must be globally unique in GCS). When omitted, the bucket name is auto-generated as `atlas-backup-{project_id}`.
    - `name_suffix` accepts a string appended to the auto-generated name, resulting in `atlas-backup-{project_id}{name_suffix}`. Include a separator (e.g. `"-dev"` produces `atlas-backup-{project_id}-dev`). Mutually exclusive with `name`.

    **Location:**
    `location` accepts GCP regions (`us-east4`), Atlas format (`US_EAST_4`),
    multi-regions (`US`, `EU`, `ASIA`), or dual-regions (`NAM4`, `EUR4`).
    Atlas format is normalized via `atlas_to_gcp_region`. Choose a region
    colocated with the Atlas cluster for lowest latency.

    **Security:**
    - `uniform_bucket_level_access` accepts `true` or `false` to control IAM-only access (no per-object ACLs). Defaults to `true`.
    - `public_access_prevention` accepts `"enforced"` to block public access or `"inherited"` to use project-level settings. Defaults to `"enforced"`.
    - `versioning_enabled` accepts `true` or `false` to enable or disable object versioning for backup recovery. Defaults to `true`.

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
    condition     = !var.backup_export.create_bucket.enabled || var.backup_export.create_bucket.location != ""
    error_message = "create_bucket.location is required when create_bucket.enabled = true."
  }

  validation {
    condition     = !(var.backup_export.create_bucket.name != "" && var.backup_export.create_bucket.name_suffix != "")
    error_message = "Cannot use both create_bucket.name and create_bucket.name_suffix."
  }

  validation {
    condition = var.backup_export.create_bucket.name == "" || can(
      regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.backup_export.create_bucket.name)
    )
    error_message = "Bucket name must be 3-63 characters, contain only lowercase letters, numbers, dots (.), underscores (_), and hyphens (-), and must start and end with a lowercase letter or number."
  }
}

variable "gcp_tags" {
  type        = map(string)
  default     = {}
  description = "Labels to apply to all GCP resources created by this module."
}
