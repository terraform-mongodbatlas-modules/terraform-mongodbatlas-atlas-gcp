mock_provider "mongodbatlas" {}
mock_provider "google" {}

variables {
  project_id = "000000000000000000000000"
}

run "global_access_true_plans" {
  command = plan
  variables {
    privatelink_endpoints = [
      { region = "us-east4", subnetwork = "sub-a", allow_psc_global_access = true }
    ]
  }
  assert {
    condition     = var.privatelink_endpoints[0].allow_psc_global_access == true
    error_message = "Expected allow_psc_global_access true on endpoint object"
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
    condition     = var.privatelink_endpoints[0].allow_psc_global_access == null
    error_message = "Expected allow_psc_global_access null when omitted"
  }
}
