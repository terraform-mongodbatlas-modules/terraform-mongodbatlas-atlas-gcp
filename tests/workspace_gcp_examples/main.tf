terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.6"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.9"
}

provider "mongodbatlas" {}
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

variable "org_id" {
  type    = string
  default = ""
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-east1"
}

variable "project_ids" {
  type = object({
    complete                 = optional(string)
    encryption               = optional(string)
    backup_export            = optional(string)
    privatelink_multi_region = optional(string)
    privatelink_byoe         = optional(string)
  })
  default = {}
}

module "project" {
  for_each = toset(local.missing_project_ids)
  source   = "../project_generator"
  org_id   = var.org_id
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

module "network_us_east4" {
  source      = "../network_generator"
  region      = "us-east4"
  subnet_cidr = "10.10.0.0/24"
  name_prefix = "atlas-pl-use4-${random_string.suffix.id}-"
}

module "network_us_east1" {
  source           = "../network_generator"
  region           = "us-east1"
  subnet_cidr      = "10.11.0.0/24"
  name_prefix      = "atlas-pl-use1-${random_string.suffix.id}-"
  existing_network = { id = module.network_us_east4.network_id }
}

locals {
  missing_project_ids = [for k, v in var.project_ids : k if v == null]
  project_ids         = { for k, v in var.project_ids : k => v != null ? v : module.project[k].project_id }
  # tflint-ignore: terraform_unused_declarations
  project_id_complete = local.project_ids.complete
  # tflint-ignore: terraform_unused_declarations
  project_id_encryption = local.project_ids.encryption
  # tflint-ignore: terraform_unused_declarations
  project_id_backup_export = local.project_ids.backup_export
  # tflint-ignore: terraform_unused_declarations
  project_id_privatelink_multi_region = local.project_ids.privatelink_multi_region
  # tflint-ignore: terraform_unused_declarations
  project_id_privatelink_byoe = local.project_ids.privatelink_byoe
  # tflint-ignore: terraform_unused_declarations
  key_ring_name = "atlas-test-${random_string.suffix.id}"
  # tflint-ignore: terraform_unused_declarations
  key_ring_name_complete = "atlas-complete-${random_string.suffix.id}"
  # tflint-ignore: terraform_unused_declarations
  privatelink_endpoints_complete = [
    { region = "us-east4", subnetwork = module.network_us_east4.subnetwork_self_link },
  ]
  # tflint-ignore: terraform_unused_declarations
  privatelink_endpoints_multi_region = [
    { region = "us-east4", subnetwork = module.network_us_east4.subnetwork_self_link },
    { region = "us-east1", subnetwork = module.network_us_east1.subnetwork_self_link },
  ]
  # tflint-ignore: terraform_unused_declarations
  subnetwork_privatelink_byoe = module.network_us_east4.subnetwork_self_link
}
