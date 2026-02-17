mock_provider "mongodbatlas" {}
mock_provider "google" {}

variables {
  project_id = "000000000000000000000000"
}

# ─────────────────────────────────────────────────────────────────────────────
# Default (no privatelink configured)
# ─────────────────────────────────────────────────────────────────────────────

run "no_privatelink_empty_outputs" {
  command = plan
  assert {
    condition     = length(output.privatelink) == 0
    error_message = "Expected empty privatelink output by default"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 0
    error_message = "Expected empty privatelink_service_info by default"
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled by default"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Module-Managed (privatelink_endpoints)
# ─────────────────────────────────────────────────────────────────────────────

run "single_region" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" }
    ]
  }
  assert {
    condition     = output.role_id == null
    error_message = "Expected null role_id when only privatelink configured (CPA skipped)"
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
  assert {
    condition     = length(output.privatelink) == 1
    error_message = "Expected one privatelink output entry"
  }
  assert {
    condition     = contains(keys(output.privatelink), "us-east4")
    error_message = "Expected privatelink output key 'us-east4'"
  }
}

run "multi_region" {
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
  assert {
    condition     = length(output.privatelink) == 2
    error_message = "Expected two privatelink output entries"
  }
}

run "atlas_region_format" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "US_EAST_4", subnetwork = "sub-a" }
    ]
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled for single region"
  }
  assert {
    condition     = contains(keys(output.privatelink_service_info), "US_EAST_4")
    error_message = "Expected privatelink_service_info key preserves Atlas format 'US_EAST_4'"
  }
  assert {
    condition     = length(output.privatelink) == 1
    error_message = "Expected one privatelink output entry with Atlas format"
  }
}

run "mixed_format_multi_region" {
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
  assert {
    condition     = length(output.privatelink) == 2
    error_message = "Expected two privatelink output entries"
  }
  assert {
    condition     = sort(keys(output.privatelink_service_info)) == sort(["US_WEST_4", "us-east4"])
    error_message = "Expected privatelink_service_info keys to match endpoint regions inputted by the user"
  }
}

run "labels_propagated" {
  command = plan
  variables {
    gcp_tags = { env = "test" }
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a", labels = { feature = "psc" } }
    ]
  }
  assert {
    condition     = length(output.privatelink) == 1
    error_message = "Expected one privatelink output entry with labels"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Single-Region Multi-VPC (privatelink_endpoints_single_region)
# ─────────────────────────────────────────────────────────────────────────────

run "single_region_multi_vpc" {
  command = plan
  variables {
    privatelink_endpoints_single_region = [
      { region = "us-east4", subnetwork = "sub-a" },
      { region = "us-east4", subnetwork = "sub-b" }
    ]
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled for single-region multi-VPC"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 2
    error_message = "Expected two privatelink_service_info entries for multi-VPC"
  }
  assert {
    condition     = length(setintersection(keys(output.privatelink_service_info), ["0", "1"])) == 2
    error_message = "Expected index-based keys '0' and '1' for single-region multi-VPC"
  }
  assert {
    condition     = length(output.privatelink) == 2
    error_message = "Expected two privatelink output entries for multi-VPC"
  }
  assert {
    condition     = length(setintersection(keys(output.privatelink), ["0", "1"])) == 2
    error_message = "Expected privatelink output keys '0' and '1'"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# BYOE (Bring Your Own Endpoint)
# ─────────────────────────────────────────────────────────────────────────────

run "byoe_phase1_only" {
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
  assert {
    condition     = length(output.privatelink) == 0
    error_message = "Expected empty privatelink output for BYOE Phase 1 (no forwarding rules)"
  }
}

run "byoe_phase2" {
  command = plan
  variables {
    privatelink_byoe_regions = { primary = "us-east4" }
    privatelink_byoe = {
      primary = { ip_address = "10.0.1.5", forwarding_rule_name = "my-fr" }
    }
  }
  assert {
    condition     = length(output.privatelink) == 1
    error_message = "Expected one privatelink output entry for BYOE Phase 2"
  }
  assert {
    condition     = contains(keys(output.privatelink), "primary")
    error_message = "Expected privatelink output key 'primary'"
  }
}

run "byoe_custom_gcp_project" {
  command = plan
  variables {
    privatelink_byoe_regions = { primary = "us-east4" }
    privatelink_byoe = {
      primary = {
        ip_address           = "10.0.1.5"
        forwarding_rule_name = "my-fr"
        gcp_project_id       = "other-project-123"
      }
    }
  }
  assert {
    condition     = output.privatelink["primary"].gcp_project_id == "other-project-123"
    error_message = "Expected custom gcp_project_id to flow through to privatelink output"
  }
}

run "byoe_partial_rollout" {
  command = plan
  variables {
    privatelink_byoe_regions = {
      primary   = "us-east4"
      secondary = "us-west4"
    }
    privatelink_byoe = {
      primary = { ip_address = "10.0.1.5", forwarding_rule_name = "fr-primary" }
    }
  }
  assert {
    condition     = output.regional_mode_enabled == true
    error_message = "Expected regional mode enabled for multi-region BYOE"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 2
    error_message = "Expected two privatelink_service_info entries (both regions declared)"
  }
  assert {
    condition     = length(output.privatelink) == 1
    error_message = "Expected one privatelink output entry (only primary has forwarding rule)"
  }
  assert {
    condition     = contains(keys(output.privatelink), "primary")
    error_message = "Expected privatelink output key 'primary' (connected region)"
  }
}

run "byoe_single_region_no_regional_mode" {
  command = plan
  variables {
    privatelink_byoe_regions = { primary = "us-east4" }
  }
  assert {
    condition     = output.regional_mode_enabled == false
    error_message = "Expected regional mode disabled for single BYOE region"
  }
  assert {
    condition     = length(output.privatelink_service_info) == 1
    error_message = "Expected one privatelink_service_info entry"
  }
  assert {
    condition     = length(output.privatelink) == 0
    error_message = "Expected empty privatelink output for BYOE Phase 1"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# PrivateLink + Other Features (CPA interaction)
# ─────────────────────────────────────────────────────────────────────────────

run "privatelink_with_encryption_creates_cpa" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" }
    ]
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected GCP encryption provider"
  }
  assert {
    condition     = length(output.privatelink) == 1
    error_message = "Expected one privatelink output entry"
  }
  assert {
    condition     = length(module.cloud_provider_access) == 1
    error_message = "Expected one cloud_provider_access module"
  }
}
