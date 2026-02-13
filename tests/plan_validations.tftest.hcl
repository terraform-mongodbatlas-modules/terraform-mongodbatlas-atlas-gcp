mock_provider "mongodbatlas" {}
mock_provider "google" {}

variables {
  project_id = "000000000000000000000000"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cloud Provider Access Validations
# ─────────────────────────────────────────────────────────────────────────────

run "cpa_create_false_requires_existing" {
  command = plan
  variables {
    cloud_provider_access = { create = false }
  }
  expect_failures = [var.cloud_provider_access]
}

run "cpa_create_true_with_existing_conflict" {
  command = plan
  variables {
    cloud_provider_access = {
      create   = true
      existing = { role_id = "abc123", service_account_for_atlas = "sa@gcp.iam" }
    }
  }
  expect_failures = [var.cloud_provider_access]
}

# ─────────────────────────────────────────────────────────────────────────────
# Encryption Validations
# ─────────────────────────────────────────────────────────────────────────────

run "encryption_byo_and_create_conflict" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
      create_kms_key          = { enabled = true, key_ring_name = "kr", crypto_key_name = "ck", location = "us-east4" }
    }
  }
  expect_failures = [var.encryption]
}

run "encryption_enabled_without_key" {
  command = plan
  variables {
    encryption = { enabled = true }
  }
  expect_failures = [var.encryption]
}

run "encryption_disabled_with_key_conflict" {
  command = plan
  variables {
    encryption = {
      enabled                 = false
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
  }
  expect_failures = [var.encryption]
}

run "encryption_create_kms_key_missing_fields" {
  command = plan
  variables {
    encryption = {
      enabled        = true
      create_kms_key = { enabled = true }
    }
  }
  expect_failures = [var.encryption]
}

# ─────────────────────────────────────────────────────────────────────────────
# PrivateLink Validations
# ─────────────────────────────────────────────────────────────────────────────

run "privatelink_duplicate_regions" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" },
      { region = "us-east4", subnetwork = "sub-b" }
    ]
  }
  expect_failures = [var.privatelink_endpoints]
}

run "privatelink_single_region_must_match" {
  command = plan
  variables {
    privatelink_endpoints_single_region = [
      { region = "us-east4", subnetwork = "sub-a" },
      { region = "us-west4", subnetwork = "sub-b" }
    ]
  }
  expect_failures = [var.privatelink_endpoints_single_region]
}

run "privatelink_cannot_mix_patterns" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" }
    ]
    privatelink_endpoints_single_region = [
      { region = "us-west4", subnetwork = "sub-b" }
    ]
  }
  expect_failures = [var.privatelink_endpoints_single_region]
}

# ─────────────────────────────────────────────────────────────────────────────
# BYOE Validations
# ─────────────────────────────────────────────────────────────────────────────

run "byoe_key_not_in_regions" {
  command = plan
  variables {
    privatelink_byoe_regions = { primary = "us-east4" }
    privatelink_byoe         = { secondary = { ip_address = "10.0.1.5", forwarding_rule_name = "fr-1" } }
  }
  expect_failures = [var.privatelink_byoe]
}

run "byoe_region_overlap_with_endpoints" {
  command = plan
  variables {
    privatelink_endpoints    = [{ region = "us-east4", subnetwork = "sub-a" }]
    privatelink_byoe_regions = { primary = "us-east4" }
  }
  expect_failures = [var.privatelink_byoe_regions]
}

# ─────────────────────────────────────────────────────────────────────────────
# Backup Export Validations
# ─────────────────────────────────────────────────────────────────────────────

run "backup_byo_and_create_conflict" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      bucket_name   = "my-bucket"
      create_bucket = { enabled = true, name = "new-bucket", location = "us-east4" }
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_enabled_without_bucket" {
  command = plan
  variables {
    backup_export = { enabled = true }
  }
  expect_failures = [var.backup_export]
}

run "backup_disabled_with_bucket_conflict" {
  command = plan
  variables {
    backup_export = {
      enabled     = false
      bucket_name = "my-bucket"
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_create_bucket_missing_location" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true }
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_name_and_suffix_conflict" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name = "my-bucket", name_suffix = "-dev", location = "us-east4" }
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_invalid_bucket_name_start" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name = "-invalid", location = "us-east4" }
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_invalid_bucket_name_uppercase" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name = "myBucket", location = "us-east4" }
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_invalid_bucket_name_too_short" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name = "ab", location = "us-east4" }
    }
  }
  expect_failures = [var.backup_export]
}

run "backup_invalid_bucket_name_end" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name = "my-bucket-", location = "us-east4" }
    }
  }
  expect_failures = [var.backup_export]
}

# ─────────────────────────────────────────────────────────────────────────────
# Valid Configuration Assertions
# ─────────────────────────────────────────────────────────────────────────────

run "default_config" {
  command = plan
  assert {
    condition     = output.encryption_at_rest_provider == "NONE"
    error_message = "Expected NONE when encryption disabled"
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled by default"
  }
}

run "encryption_provider_gcp" {
  command = plan
  variables {
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected GCP when encryption enabled"
  }
}

run "privatelink_only_skips_cpa" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" }
    ]
  }
  assert {
    condition     = output.role_id == null
    error_message = "Expected null role_id when only privatelink configured"
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled for single region"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 1
    error_message = "Expected one privatelink_service_info entry"
  }
  assert {
    condition     = contains(keys(output.privatelink_service_info), "us-east4")
    error_message = "Expected privatelink_service_info key 'us-east4'"
  }
}

run "existing_cpa_flows_through" {
  command = plan
  variables {
    cloud_provider_access = {
      create   = false
      existing = { role_id = "existing-role-123", service_account_for_atlas = "sa@gcp.iam" }
    }
  }
  assert {
    condition     = output.role_id == "existing-role-123"
    error_message = "Expected existing role_id to flow through"
  }
}

run "atlas_region_format_in_privatelink" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "US_EAST_4", subnetwork = "sub-a" }
    ]
  }
  assert {
    condition     = output.role_id == null
    error_message = "Expected null role_id when only privatelink configured"
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled for single region"
  }
  assert {
    condition     = contains(keys(output.privatelink_service_info), "US_EAST_4")
    error_message = "Expected privatelink_service_info key 'US_EAST_4' for Atlas format input"
  }
}

run "regional_mode_multi_region" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" },
      { region = "us-west4", subnetwork = "sub-b" }
    ]
  }
  assert {
    condition     = output.regional_mode_enabled == true
    error_message = "Expected regional mode enabled for multi-region"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 2
    error_message = "Expected two privatelink_service_info entries"
  }
  assert {
    condition     = length(setintersection(keys(output.privatelink_service_info), ["us-east4", "us-west4"])) == 2
    error_message = "Expected privatelink_service_info keys to match endpoint regions"
  }
}

run "regional_mode_byoe_multi_region" {
  command = plan
  variables {
    privatelink_byoe_regions = {
      primary   = "us-east4"
      secondary = "us-west4"
    }
  }
  assert {
    condition     = output.regional_mode_enabled == true
    error_message = "Expected regional mode enabled for multi-region BYOE"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 2
    error_message = "Expected two privatelink_service_info entries for BYOE"
  }
  assert {
    condition     = length(setintersection(keys(output.privatelink_service_info), ["primary", "secondary"])) == 2
    error_message = "Expected privatelink_service_info keys to match BYOE region keys"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Region Normalization Validations (preconditions on terraform_data)
# ─────────────────────────────────────────────────────────────────────────────

run "region_unknown_rejected" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "invalid-region", subnetwork = "sub-a" }
    ]
  }
  expect_failures = [terraform_data.region_validations]
}

run "region_cross_format_duplicate" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" },
      { region = "US_EAST_4", subnetwork = "sub-b" }
    ]
  }
  expect_failures = [terraform_data.region_validations]
}

run "region_cross_format_byoe_overlap" {
  command = plan
  variables {
    privatelink_endpoints    = [{ region = "us-east4", subnetwork = "sub-a" }]
    privatelink_byoe_regions = { primary = "US_EAST_4" }
  }
  expect_failures = [terraform_data.region_validations]
}

run "region_unknown_single_region_rejected" {
  command = plan
  variables {
    privatelink_endpoints_single_region = [
      { region = "invalid-region", subnetwork = "sub-a" }
    ]
  }
  expect_failures = [terraform_data.region_validations]
}

run "region_unknown_byoe_rejected" {
  command = plan
  variables {
    privatelink_byoe_regions = { primary = "invalid-region" }
  }
  expect_failures = [terraform_data.region_validations]
}

run "region_mixed_format_multi_region" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" },
      { region = "US_WEST_4", subnetwork = "sub-b" }
    ]
  }
  assert {
    condition     = output.regional_mode_enabled == true
    error_message = "Expected regional mode enabled for mixed-format multi-region"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 2
    error_message = "Expected two privatelink_service_info entries"
  }
}

run "region_custom_mapping_override" {
  command = plan
  variables {
    atlas_to_gcp_region = {
      US_EAST_99 = "us-east4"
    }
    privatelink_endpoints = [
      { region = "US_EAST_99", subnetwork = "sub-a" }
    ]
  }
  assert {
    condition     = length(output.privatelink_service_info) == 1
    error_message = "Expected one entry with custom mapping"
  }
}
