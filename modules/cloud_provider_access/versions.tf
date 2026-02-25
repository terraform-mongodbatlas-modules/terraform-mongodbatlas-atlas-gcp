terraform {
  required_version = ">= 1.9"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.7"
    }
  }

  provider_meta "mongodbatlas" {
    module_name    = "atlas-gcp"
    module_version = "0.1.0"
  }
}
