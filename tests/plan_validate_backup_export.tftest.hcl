mock_provider "mongodbatlas" {}
mock_provider "google" {}

variables {
  project_id = "000000000000000000000000"
}

# ─────────────────────────────────────────────────────────────────────────────
# Disabled Default
# ─────────────────────────────────────────────────────────────────────────────

run "backup_export_disabled_default" {
  command = plan
  assert {
    condition     = output.export_bucket_id == null
    error_message = "Expected null export_bucket_id when disabled"
  }
  assert {
    condition     = output.backup_export == null
    error_message = "Expected null backup_export output when disabled"
  }
  assert {
    condition     = output.resource_ids.bucket_name == null
    error_message = "Expected null bucket_name in resource_ids when disabled"
  }
  assert {
    condition     = output.resource_ids.bucket_url == null
    error_message = "Expected null bucket_url in resource_ids when disabled"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Module-Managed Bucket
# ─────────────────────────────────────────────────────────────────────────────

run "backup_export_create_bucket_explicit_name" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name = "my-atlas-bucket", location = "us-east4" }
    }
  }
  assert {
    condition     = output.resource_ids.bucket_name == "my-atlas-bucket"
    error_message = "Expected bucket_name to match explicit name"
  }
}

run "backup_export_create_bucket_default_name" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, location = "us-east4" }
    }
  }
  assert {
    condition     = startswith(output.resource_ids.bucket_name, "atlas-backup-")
    error_message = "Expected default bucket_name to start with atlas-backup-"
  }
  assert {
    condition     = strcontains(output.resource_ids.bucket_name, "000000000000000000000000")
    error_message = "Expected default bucket_name to contain project_id"
  }
}

run "backup_export_create_bucket_with_suffix" {
  command = plan
  variables {
    backup_export = {
      enabled       = true
      create_bucket = { enabled = true, name_suffix = "-dev", location = "us-east4" }
    }
  }
  assert {
    condition     = endswith(output.resource_ids.bucket_name, "-dev")
    error_message = "Expected bucket_name to end with -dev suffix"
  }
  assert {
    condition     = startswith(output.resource_ids.bucket_name, "atlas-backup-")
    error_message = "Expected bucket_name to start with atlas-backup-"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# User-Provided Bucket
# ─────────────────────────────────────────────────────────────────────────────

run "backup_export_user_bucket" {
  command = plan
  variables {
    backup_export = {
      enabled     = true
      bucket_name = "existing-bucket"
    }
  }
  assert {
    condition     = output.resource_ids.bucket_name == "existing-bucket"
    error_message = "Expected bucket_name to match user-provided name"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Dedicated Role
# ─────────────────────────────────────────────────────────────────────────────

run "backup_export_dedicated_role" {
  command = plan
  variables {
    backup_export = {
      enabled                = true
      bucket_name            = "existing-bucket"
      dedicated_role_enabled = true
    }
  }
  assert {
    condition     = output.resource_ids.bucket_name == "existing-bucket"
    error_message = "Expected bucket_name with dedicated role"
  }
}
