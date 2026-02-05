mock_provider "google" {}

run "validate_network_name_not_empty" {
  command = plan
  module {
    source = "./examples/auth-check"
  }
  variables {
    network_name = ""
  }
  expect_failures = [var.network_name]
}

run "valid_config" {
  command = plan
  module {
    source = "./examples/auth-check"
  }
  variables {
    network_name = "test-vpc"
  }
}
