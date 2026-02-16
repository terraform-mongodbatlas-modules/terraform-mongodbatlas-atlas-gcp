terraform {
  required_version = ">= 1.9"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = ">= 2.6"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }

  provider_meta "mongodbatlas" {
    module_name    = "atlas-gcp/privatelink"
    module_version = "local"
  }
}
