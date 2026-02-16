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

variable "existing_network" {
  type = object({
    id = string
  })
  default     = null
  description = "Existing VPC network. If null, a new network is created."
}

locals {
  create_network = var.existing_network == null
}

resource "google_compute_network" "this" {
  count                   = local.create_network ? 1 : 0
  name                    = "${var.name_prefix}vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.name_prefix}subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = local.create_network ? google_compute_network.this[0].id : var.existing_network.id
}

output "network_id" {
  value = local.create_network ? google_compute_network.this[0].id : var.existing_network.id
}

output "subnetwork_self_link" {
  value = google_compute_subnetwork.this.self_link
}
