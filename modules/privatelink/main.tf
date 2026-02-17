locals {
  provider_name  = "GCP"
  module_managed = var.subnetwork != null
}

data "google_compute_subnetwork" "atlas" {
  count     = local.module_managed ? 1 : 0
  self_link = var.subnetwork.self_link
}

data "google_client_config" "current" {}

resource "google_compute_address" "atlas" {
  count        = local.module_managed ? 1 : 0
  name         = "${var.name_prefix}ip"
  region       = var.gcp_region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork.self_link
  labels       = var.labels
}

resource "google_compute_forwarding_rule" "atlas" {
  count                 = local.module_managed ? 1 : 0
  name                  = "${var.name_prefix}fr"
  region                = var.gcp_region
  network               = data.google_compute_subnetwork.atlas[0].network
  ip_address            = google_compute_address.atlas[0].id
  load_balancing_scheme = ""
  target                = var.service_attachment_name
  labels                = var.labels
}

locals {
  endpoint_ip   = local.module_managed ? google_compute_address.atlas[0].address : var.byo.ip_address
  endpoint_name = local.module_managed ? google_compute_forwarding_rule.atlas[0].name : var.byo.forwarding_rule_name
  gcp_project   = local.module_managed ? data.google_compute_subnetwork.atlas[0].project : coalesce(var.byo.gcp_project_id, data.google_client_config.current.project)
}

resource "mongodbatlas_privatelink_endpoint_service" "this" {
  project_id                  = var.project_id
  private_link_id             = var.private_link_id
  provider_name               = local.provider_name
  gcp_project_id              = local.gcp_project
  endpoint_service_id         = local.endpoint_name
  private_endpoint_ip_address = local.endpoint_ip
}

data "mongodbatlas_privatelink_endpoint_service" "this" {
  project_id          = var.project_id
  private_link_id     = var.private_link_id
  endpoint_service_id = mongodbatlas_privatelink_endpoint_service.this.endpoint_service_id
  provider_name       = local.provider_name
  depends_on          = [mongodbatlas_privatelink_endpoint_service.this]
}
