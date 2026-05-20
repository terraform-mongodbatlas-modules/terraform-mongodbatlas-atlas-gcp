mock_provider "mongodbatlas" {}
mock_provider "google" {}
mock_provider "time" {}

variables {
  project_id = "000000000000000000000000"
}

run "log_integration_disabled_default" {
  command = plan
  assert {
    condition     = output.log_integration == null
    error_message = "Expected null log_integration output when disabled"
  }
  assert {
    condition     = output.resource_ids.log_bucket_name == null
    error_message = "Expected null log_bucket_name when disabled"
  }
}

run "log_integration_create_bucket_default_name" {
  command = plan
  variables {
    log_integration = {
      enabled = true
      create_gcs_bucket = {
        enabled  = true
        location = "us-east4"
      }
      integrations = [{ log_types = ["MONGOD"] }]
    }
  }
  assert {
    condition     = startswith(output.resource_ids.log_bucket_name, "atlas-logs-")
    error_message = "Expected default log bucket name prefix atlas-logs-"
  }
}

run "log_integration_user_bucket" {
  command = plan
  variables {
    log_integration = {
      enabled      = true
      bucket_name  = "existing-logs-bucket"
      integrations = [{ log_types = ["MONGOD", "MONGOS"] }]
    }
  }
  assert {
    condition     = output.resource_ids.log_bucket_name == "existing-logs-bucket"
    error_message = "Expected user-provided log bucket name"
  }
}

run "log_integration_atlas_region_format" {
  command = plan
  variables {
    log_integration = {
      enabled = true
      create_gcs_bucket = {
        enabled  = true
        location = "US_EAST_4"
      }
      integrations = [{ log_types = ["MONGOD"] }]
    }
  }
  assert {
    condition     = output.log_integration != null
    error_message = "Expected non-null log_integration with Atlas region format"
  }
}

run "log_integration_expiration_days_zero" {
  command = plan
  variables {
    log_integration = {
      enabled = true
      create_gcs_bucket = {
        enabled         = true
        location        = "us-east4"
        expiration_days = 0
      }
      integrations = [{ log_types = ["MONGOD"] }]
    }
  }
  assert {
    condition     = output.log_integration != null
    error_message = "Expected non-null log_integration when expiration_days = 0"
  }
}
