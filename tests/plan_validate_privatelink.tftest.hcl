mock_provider "mongodbatlas" {}
mock_provider "google" {}
mock_provider "time" {}

variables {
  project_id = "000000000000000000000000"
}

run "byoe_overlap_after_normalization" {
  command = plan
  variables {
    privatelink_endpoints    = [{ region = "us-east4", subnetwork = "sub-a" }]
    privatelink_byo_endpoint = { primary = { region = "US_EAST_4" } }
  }
  expect_failures = [terraform_data.region_validations]
}

run "byoe_service_key_missing" {
  command = plan
  variables {
    privatelink_byo_endpoint = { primary = { region = "us-east4" } }
    privatelink_byo_service  = { secondary = { ip_address = "10.0.1.5", forwarding_rule_name = "fr-1" } }
  }
  expect_failures = [var.privatelink_byo_service]
}

run "privatelink_byo_valid" {
  command = plan
  variables {
    privatelink_byo_endpoint = { primary = { region = "us-east4" } }
    privatelink_byo_service = {
      primary = { ip_address = "10.0.1.5", forwarding_rule_name = "fr-1" }
    }
  }
}
