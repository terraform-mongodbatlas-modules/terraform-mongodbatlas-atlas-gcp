resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "primary" {
  name                     = "${var.network_name}-primary"
  region                   = "us-east1"
  network                  = google_compute_network.main.id
  ip_cidr_range            = "10.0.0.0/24"
  private_ip_google_access = true
}
