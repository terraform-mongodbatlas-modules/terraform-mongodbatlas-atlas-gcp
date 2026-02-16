terraform {
  required_version = ">= 1.9"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.6" # TODO(CLOUDP-381477): temporary until provider ~> 2.7 is released
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }

  provider_meta "mongodbatlas" {
    module_name    = "atlas-gcp"
    module_version = "local"
  }
}

provider "mongodbatlas" {}
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
