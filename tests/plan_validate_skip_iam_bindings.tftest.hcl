mock_provider "mongodbatlas" {}
mock_provider "google" {}
mock_provider "time" {}

variables {
  project_id = "000000000000000000000000"
}

run "skip_with_module_kms_fails" {
  command = plan
  variables {
    skip_iam_bindings = true
    encryption = {
      enabled        = true
      create_kms_key = { enabled = true, location = "us-east4" }
    }
    cloud_provider_access = {
      create   = false
      existing = { role_id = "abc123", service_account_for_atlas = "sa@gcp.iam" }
    }
  }
  expect_failures = [var.skip_iam_bindings]
}

run "skip_with_module_backup_bucket_fails" {
  command = plan
  variables {
    skip_iam_bindings = true
    backup_export = {
      enabled           = true
      create_gcs_bucket = { enabled = true, location = "us-east4" }
    }
    cloud_provider_access = {
      create   = false
      existing = { role_id = "abc123", service_account_for_atlas = "sa@gcp.iam" }
    }
  }
  expect_failures = [var.skip_iam_bindings]
}

run "skip_with_module_log_bucket_fails" {
  command = plan
  variables {
    skip_iam_bindings = true
    log_integration = {
      enabled = true
      create_gcs_bucket = {
        enabled  = true
        location = "us-east4"
      }
      integrations = [{ log_types = ["MONGOD"], prefix_path = "logs" }]
    }
    cloud_provider_access = {
      create   = false
      existing = { role_id = "abc123", service_account_for_atlas = "sa@gcp.iam" }
    }
  }
  expect_failures = [var.skip_iam_bindings]
}

run "skip_with_cpa_create_fails" {
  command = plan
  variables {
    skip_iam_bindings = true
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/l/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
  }
  expect_failures = [var.skip_iam_bindings]
}

run "skip_read_only_byo_valid" {
  command = plan
  variables {
    skip_iam_bindings = true
    cloud_provider_access = {
      create = false
      existing = {
        role_id                   = "abc123def456ghi789jkl012"
        service_account_for_atlas = "atlas-sa@test.iam.gserviceaccount.com"
      }
    }
    encryption = {
      enabled                 = true
      key_version_resource_id = "projects/p/locations/us-east4/keyRings/kr/cryptoKeys/ck/cryptoKeyVersions/1"
    }
    backup_export = {
      enabled     = true
      bucket_name = "byo-backup-bucket"
    }
    log_integration = {
      enabled      = true
      bucket_name  = "byo-logs-bucket"
      integrations = [{ log_types = ["MONGOD"], prefix_path = "logs" }]
    }
  }
  assert {
    condition     = output.encryption != null
    error_message = "Expected non-null encryption output"
  }
  assert {
    condition     = output.backup_export != null
    error_message = "Expected non-null backup_export output"
  }
  assert {
    condition     = output.log_integration != null
    error_message = "Expected non-null log_integration output"
  }
}
