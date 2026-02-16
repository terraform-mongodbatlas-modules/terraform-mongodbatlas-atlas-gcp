terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
  required_version = ">= 1.9"
}

variable "region" {
  type    = string
  default = "us-east4"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "name_prefix" {
  type    = string
  default = "atlas-workspace-"
}

variable "create_network" {
  type    = bool
  default = true
}

variable "network_id" {
  type        = string
  default     = null
  description = "Existing VPC network ID. Required when create_network = false."

  validation {
    condition     = var.create_network || var.network_id != null
    error_message = "network_id is required when create_network = false."
  }
}

resource "google_compute_network" "this" {
  count                   = var.create_network ? 1 : 0
  name                    = "${var.name_prefix}vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.name_prefix}subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = var.create_network ? google_compute_network.this[0].id : var.network_id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

output "network_id" {
  value = var.create_network ? google_compute_network.this[0].id : var.network_id
}

output "subnetwork_self_link" {
  value = google_compute_subnetwork.this.self_link
}
