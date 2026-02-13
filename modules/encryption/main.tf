locals {
  create_kms_key = var.create_kms_key.enabled

  # Key ring gets project ID prefix to avoid collisions across Atlas projects in the same GCP project+location
  # Prefix with "atlas-" to guarantee the name starts with a letter (GCP requirement)
  # GCP key ring names: 1-63 chars, [a-zA-Z][a-zA-Z0-9_-]*
  # Auto-generated: "atlas-" (6) + project_id (24 hex) + "-keyring" (8) = 38 chars
  # Crypto key name needs no prefix -- it's already scoped within the key ring
  key_ring_name   = var.create_kms_key.key_ring_name != null ? var.create_kms_key.key_ring_name : "atlas-${var.project_id}-keyring"
  crypto_key_name = var.create_kms_key.crypto_key_name != null ? var.create_kms_key.crypto_key_name : "atlas-encryption-key"

  key_version_resource_id = local.create_kms_key ? (
    google_kms_crypto_key.atlas[0].primary[0].name
  ) : var.key_version_resource_id

  # Derive crypto_key_id and kms_location from key_version_resource_id for user-provided keys
  # Format: projects/{p}/locations/{l}/keyRings/{kr}/cryptoKeys/{ck}/cryptoKeyVersions/{v}
  _kvri_parts = local.create_kms_key ? null : regex(
    "projects/[^/]+/locations/(?P<location>[^/]+)/keyRings/[^/]+/cryptoKeys/(?P<crypto_key>[^/]+)/cryptoKeyVersions/",
    var.key_version_resource_id
  )

  crypto_key_id = local.create_kms_key ? (
    google_kms_crypto_key.atlas[0].id
  ) : regex("(.+)/cryptoKeyVersions/", var.key_version_resource_id)[0]

  kms_location = local.create_kms_key ? var.create_kms_key.location : local._kvri_parts.location
}

# Module-Managed KMS Key (when create_kms_key.enabled = true)

resource "google_kms_key_ring" "atlas" {
  count    = local.create_kms_key ? 1 : 0
  name     = local.key_ring_name
  location = var.create_kms_key.location
}

resource "google_kms_crypto_key" "atlas" {
  count           = local.create_kms_key ? 1 : 0
  name            = local.crypto_key_name
  key_ring        = google_kms_key_ring.atlas[0].id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = var.create_kms_key.rotation_period
  labels          = var.labels
}

# IAM Bindings (grants Atlas SA access to KMS key)

resource "google_kms_crypto_key_iam_member" "encrypter" {
  crypto_key_id = local.crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.atlas_service_account_email}"
}

resource "google_kms_crypto_key_iam_member" "viewer" {
  crypto_key_id = local.crypto_key_id
  role          = "roles/cloudkms.viewer"
  member        = "serviceAccount:${var.atlas_service_account_email}"
}

# Atlas Encryption at Rest

resource "mongodbatlas_encryption_at_rest" "this" {
  project_id = var.project_id

  google_cloud_kms_config {
    enabled                 = true
    key_version_resource_id = local.key_version_resource_id
    role_id                 = var.role_id
  }

  lifecycle {
    postcondition {
      condition     = self.google_cloud_kms_config[0].valid
      error_message = "Google Cloud KMS config is not valid"
    }
  }

  depends_on = [
    google_kms_crypto_key_iam_member.encrypter,
    google_kms_crypto_key_iam_member.viewer
  ]
}
