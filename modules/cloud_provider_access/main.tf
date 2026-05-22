resource "mongodbatlas_cloud_provider_access_setup" "this" {
  project_id    = var.project_id
  provider_name = "GCP"

  dynamic "timeouts" {
    for_each = var.timeouts[*]
    content {
      create = timeouts.value.create
    }
  }
}

resource "mongodbatlas_cloud_provider_access_authorization" "this" {
  project_id = var.project_id
  role_id    = mongodbatlas_cloud_provider_access_setup.this.role_id
}
