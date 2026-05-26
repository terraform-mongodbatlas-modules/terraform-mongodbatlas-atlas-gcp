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
    condition     = local.privatelink_module_managed["us-east4"].all_region_mode == true
    error_message = "Expected all_region_mode to pass through to module call"
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
    condition     = local.privatelink_module_managed["us-east4"].all_region_mode == null
    error_message = "Expected all_region_mode null when omitted"
  }
}
