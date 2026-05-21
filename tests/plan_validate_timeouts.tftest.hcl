mock_provider "mongodbatlas" {}
mock_provider "google" {}
mock_provider "time" {}

variables {
  project_id = "000000000000000000000000"
}

run "timeouts_null_default" {
  command = plan
  variables {
    timeouts = null
  }
}

run "timeouts_default_encryption" {
  command = plan
  variables {
    timeouts = {}
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
  }
  assert {
    condition     = output.encryption_at_rest_provider == "GCP"
    error_message = "Expected encryption enabled with default timeouts"
  }
}

run "timeouts_null_privatelink" {
  command = plan
  variables {
    timeouts = null
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "https://www.googleapis.com/compute/v1/projects/p/regions/us-east4/subnetworks/sub" },
    ]
  }
  assert {
    condition     = length(output.privatelink_service_info) == 1
    error_message = "Expected privatelink with null timeouts"
  }
}

run "timeouts_partial_log_integration" {
  command = plan
  variables {
    timeouts = { create = "1h" }
    log_integration = {
      enabled      = true
      bucket_name  = "my-logs-bucket"
      integrations = [{ log_types = ["MONGOD"], prefix_path = "logs" }]
    }
  }
  assert {
    condition     = output.log_integration != null
    error_message = "Expected log integration with partial timeout override"
  }
}
