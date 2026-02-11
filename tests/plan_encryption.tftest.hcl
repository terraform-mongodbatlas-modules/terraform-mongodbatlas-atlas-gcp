mock_provider "mongodbatlas" {}
mock_provider "google" {}

variables {
  project_id = "000000000000000000000000"
}

# ─────────────────────────────────────────────────────────────────────────────
# key_version_resource_id Format Validation
# ─────────────────────────────────────────────────────────────────────────────

run "kvri_invalid_format_rejected" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "not-a-valid-path"
    }
  }
  expect_failures = [var.encryption]
}

run "kvri_missing_version_segment" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck"
    }
  }
  expect_failures = [var.encryption]
}

run "kvri_valid_format_accepted" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/my-project/locations/us-east4/keyRings/atlas-kr/cryptoKeys/atlas-ck/cryptoKeyVersions/1"
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected GCP when encryption enabled with valid key"
  }
  assert {
    condition     = output.encryption != null
    error_message = "Expected encryption output to be non-null"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Encryption Variable Validations
# ─────────────────────────────────────────────────────────────────────────────

run "encryption_mutual_exclusion_rejected" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
      create_kms_key          = { enabled = true, location = "us-east4" }
    }
  }
  expect_failures = [var.encryption]
}

run "encryption_enabled_without_source_rejected" {
  command = plan
  variables {
    encryption = { enabled = true }
  }
  expect_failures = [var.encryption]
}

run "encryption_key_source_when_disabled_rejected" {
  command = plan
  variables {
    encryption = {
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
  }
  expect_failures = [var.encryption]
}

# ─────────────────────────────────────────────────────────────────────────────
# Encryption Module Wiring
# ─────────────────────────────────────────────────────────────────────────────

run "encryption_create_kms_key_valid" {
  command = plan
  variables {
    encryption = {
      enabled = true
      create_kms_key = {
        enabled         = true
        key_ring_name   = "atlas-keyring"
        crypto_key_name = "atlas-key"
        location        = "us-east4"
      }
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected GCP with module-managed key"
  }
  assert {
    condition     = output.encryption != null
    error_message = "Expected encryption output to be non-null"
  }
}

run "encryption_disabled_outputs_null" {
  command = plan
  assert {
    condition     = output.encryption == null
    error_message = "Expected null encryption output when disabled"
  }
  assert {
    condition     = output.resource_ids.crypto_key_id == null
    error_message = "Expected null crypto_key_id when encryption disabled"
  }
  assert {
    condition     = output.resource_ids.key_ring_id == null
    error_message = "Expected null key_ring_id when encryption disabled"
  }
}

run "encryption_with_dedicated_role" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
      dedicated_role_enabled  = true
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected GCP with dedicated role"
  }
}

run "encryption_create_kms_key_defaults_only_location_required" {
  command = plan
  variables {
    encryption = {
      enabled = true
      create_kms_key = {
        enabled  = true
        location = "us-east4"
      }
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected GCP with defaulted key names"
  }
  assert {
    condition     = output.encryption != null
    error_message = "Expected encryption output to be non-null with defaults"
  }
}

run "encryption_create_kms_key_missing_location" {
  command = plan
  variables {
    encryption = {
      enabled        = true
      create_kms_key = { enabled = true }
    }
  }
  expect_failures = [var.encryption]
}
