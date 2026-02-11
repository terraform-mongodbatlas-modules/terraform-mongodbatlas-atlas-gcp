locals {
  create_kms_key = var.create_kms_key.enabled

  key_version_resource_id = local.create_kms_key ? (
    google_kms_crypto_key.atlas[0].primary[0].name
  ) : var.key_version_resource_id

  # Derive crypto_key_id for IAM bindings
  # Format: projects/{p}/locations/{l}/keyRings/{kr}/cryptoKeys/{ck}/cryptoKeyVersions/{v}
  crypto_key_id = local.create_kms_key ? (
    google_kms_crypto_key.atlas[0].id
  ) : regex("(.+)/cryptoKeyVersions/", var.key_version_resource_id)[0]
}

# Module-Managed KMS Key (when create_kms_key.enabled = true)

resource "google_kms_key_ring" "atlas" {
  count    = local.create_kms_key ? 1 : 0
  name     = var.create_kms_key.key_ring_name
  location = var.create_kms_key.location
}

resource "google_kms_crypto_key" "atlas" {
  count           = local.create_kms_key ? 1 : 0
  name            = var.create_kms_key.crypto_key_name
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
