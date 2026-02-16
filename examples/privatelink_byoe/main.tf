# BYOE (Bring Your Own Endpoint) pattern for GCP Private Service Connect
#
# Single `terraform apply` approach:
# 1: Create Atlas-side PrivateLink using `privatelink_byoe_regions` to get service attachment info
# 2: Create your own GCP address + forwarding rule using `privatelink_service_info` output
# 3: Register your endpoint with Atlas using `privatelink_byoe` to complete the connection

locals {
  ep1 = "ep1"
}

module "atlas_gcp" {
  source     = "../../"
  project_id = var.project_id

  privatelink_byoe = {
    (local.ep1) = {
      ip_address           = google_compute_address.psc.address
      forwarding_rule_name = google_compute_forwarding_rule.psc.name
    }
  }
  privatelink_byoe_regions = { (local.ep1) = var.gcp_region }

  gcp_tags = var.gcp_tags
}

data "google_compute_subnetwork" "psc" {
  self_link = var.subnetwork
}

resource "google_compute_address" "psc" {
  name         = "atlas-psc-address"
  region       = var.gcp_region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
}

resource "google_compute_forwarding_rule" "psc" {
  name                  = "atlas-psc-rule"
  region                = var.gcp_region
  network               = data.google_compute_subnetwork.psc.network
  ip_address            = google_compute_address.psc.id
  target                = module.atlas_gcp.privatelink_service_info[local.ep1].service_attachment_names[0]
  load_balancing_scheme = ""
}

output "privatelink" {
  description = "PrivateLink connection details"
  value       = module.atlas_gcp.privatelink[local.ep1]
}

output "forwarding_rule_id" {
  description = "GCP forwarding rule ID"
  value       = google_compute_forwarding_rule.psc.id
}

output "resource_ids" {
  description = "All resource IDs created by the module"
  value       = module.atlas_gcp.resource_ids
}
