mock_provider "mongodbatlas" {}
mock_provider "google" {}

variables {
  project_id = "000000000000000000000000"
}

run "global_access_true_plans" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a", all_region_mode = true }
    ]
  }
  assert {
    condition     = var.privatelink_endpoints[0].all_region_mode == true
    error_message = "Expected all_region_mode true on endpoint object"
  }
}

run "global_access_omitted_plans" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a" }
    ]
  }
  assert {
    condition     = var.privatelink_endpoints[0].all_region_mode == null
    error_message = "Expected all_region_mode null when omitted"
  }
}
