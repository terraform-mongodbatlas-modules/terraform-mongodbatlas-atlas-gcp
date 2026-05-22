/*
  Timeouts are resource meta-arguments (timeouts {}). They are not exposed as plannable
  resource attributes, so we cannot assert on timeout values in plan output.
  We verify variable defaults/overrides and rely on plan success to confirm dynamic
  timeout blocks are syntactically valid across all timeout-capable resource types.
*/

mock_provider "mongodbatlas" {}
mock_provider "google" {}
mock_provider "time" {}

variables {
  project_id = "000000000000000000000000"
}

run "timeouts_default_values" {
  command = plan
  assert {
    condition     = var.timeouts.create == "30m"
    error_message = "Expected create timeout default 30m"
  }
  assert {
    condition     = var.timeouts.update == "30m"
    error_message = "Expected update timeout default 30m"
  }
  assert {
    condition     = var.timeouts.delete == "30m"
    error_message = "Expected delete timeout default 30m"
  }
}

run "timeouts_custom_override" {
  command = plan
  variables {
    timeouts = { create = "1h" }
  }
  assert {
    condition     = var.timeouts.create == "1h"
    error_message = "Expected create timeout 1h when overridden"
  }
  assert {
    condition     = var.timeouts.update == "30m"
    error_message = "Expected update timeout default 30m when not overridden"
  }
  assert {
    condition     = var.timeouts.delete == "30m"
    error_message = "Expected delete timeout default 30m when not overridden"
  }
}

run "timeouts_explicit_null" {
  command = plan
  variables {
    timeouts = null
  }
  assert {
    condition     = var.timeouts == null
    error_message = "Expected timeouts to be null"
  }
}

run "timeouts_null_all_features" {
  command = plan
  variables {
    timeouts = null
    encryption = {
      enabled        = true
      create_kms_key = { enabled = true, location = "us-east4" }
    }
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "https://www.googleapis.com/compute/v1/projects/p/regions/us-east4/subnetworks/sub-a" },
      { region = "us-west4", subnetwork = "https://www.googleapis.com/compute/v1/projects/p/regions/us-west4/subnetworks/sub-b" },
    ]
    backup_export = {
      enabled           = true
      create_gcs_bucket = { enabled = true, location = "us-east4" }
    }
    log_integration = {
      enabled           = true
      create_gcs_bucket = { enabled = true, location = "us-east4" }
      integrations      = [{ log_types = ["MONGOD"], prefix_path = "logs" }]
    }
  }
  assert {
    condition     = length(module.cloud_provider_access) == 1
    error_message = "Expected cloud_provider_access module"
  }
  assert {
    condition     = length(module.encryption) == 1
    error_message = "Expected encryption module"
  }
  assert {
    condition     = length(module.privatelink) == 2
    error_message = "Expected 2 privatelink modules"
  }
  assert {
    condition     = length(module.backup_export) == 1
    error_message = "Expected backup_export module"
  }
  assert {
    condition     = length(module.log_integration) == 1
    error_message = "Expected log_integration module"
  }
}

run "timeouts_all_resources_plan_succeeds" {
  command = plan
  variables {
    timeouts = { create = "45m", update = "45m", delete = "45m" }
    encryption = {
      enabled        = true
      create_kms_key = { enabled = true, location = "us-east4" }
    }
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "https://www.googleapis.com/compute/v1/projects/p/regions/us-east4/subnetworks/sub-a" },
      { region = "us-west4", subnetwork = "https://www.googleapis.com/compute/v1/projects/p/regions/us-west4/subnetworks/sub-b" },
    ]
    backup_export = {
      enabled           = true
      create_gcs_bucket = { enabled = true, location = "us-east4" }
    }
    log_integration = {
      enabled           = true
      create_gcs_bucket = { enabled = true, location = "us-east4" }
      integrations      = [{ log_types = ["MONGOD"], prefix_path = "logs" }]
    }
  }
  assert {
    condition     = length(module.cloud_provider_access) == 1
    error_message = "Expected cloud_provider_access module (timeout path exercised)"
  }
  assert {
    condition     = length(module.encryption) == 1
    error_message = "Expected encryption module (timeout path exercised)"
  }
  assert {
    condition     = length(module.privatelink) == 2
    error_message = "Expected 2 privatelink modules (timeout path exercised)"
  }
  assert {
    condition     = length(mongodbatlas_private_endpoint_regional_mode.this) == 1
    error_message = "Expected regional_mode resource (timeout path exercised)"
  }
  assert {
    condition     = length(mongodbatlas_privatelink_endpoint.this) == 2
    error_message = "Expected 2 privatelink endpoint resources (timeout path exercised)"
  }
  assert {
    condition     = length(module.backup_export) == 1
    error_message = "Expected backup_export module (timeout path exercised)"
  }
  assert {
    condition     = length(module.log_integration) == 1
    error_message = "Expected log_integration module (timeout path exercised)"
  }
}
