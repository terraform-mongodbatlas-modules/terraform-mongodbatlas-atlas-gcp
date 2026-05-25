terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.8"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
  required_version = ">= 1.9"
}

provider "mongodbatlas" {}
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
provider "time" {}

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
    log_integration          = optional(string)
    privatelink_multi_region = optional(string)
    privatelink_byoe         = optional(string)
    gcp_read_only            = optional(string)
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
  project_id_log_integration = local.project_ids.log_integration
  # tflint-ignore: terraform_unused_declarations
  project_id_privatelink_multi_region = local.project_ids.privatelink_multi_region
  # tflint-ignore: terraform_unused_declarations
  project_id_privatelink_byoe = local.project_ids.privatelink_byoe
  # tflint-ignore: terraform_unused_declarations
  project_id_gcp_read_only = local.project_ids.gcp_read_only
  # tflint-ignore: terraform_unused_declarations
  key_ring_name = "atlas-test-${random_string.suffix.id}"
  # tflint-ignore: terraform_unused_declarations
  key_ring_name_complete = "atlas-complete-${random_string.suffix.id}"
  # tflint-ignore: terraform_unused_declarations
  privatelink_endpoints_complete = [
    { region = "us-east4", subnetwork = module.network_us_east4.subnetwork_self_link, name_prefix = "atlas-psc-cpl-" },
  ]
  # tflint-ignore: terraform_unused_declarations
  privatelink_endpoints_multi_region = [
    { region = "us-east4", subnetwork = module.network_us_east4.subnetwork_self_link },
    { region = "us-east1", subnetwork = module.network_us_east1.subnetwork_self_link },
  ]
  # tflint-ignore: terraform_unused_declarations
  subnetwork_privatelink_byoe = module.network_us_east4.subnetwork_self_link
  # tflint-ignore: terraform_unused_declarations
  atlas_role_id_gcp_read_only = "000000000000000000000001"
  # tflint-ignore: terraform_unused_declarations
  atlas_service_account_email_gcp_read_only = "atlas-readonly@${var.gcp_project_id}.iam.gserviceaccount.com"
}

# BYO stand-ins for ex_gcp_read_only: KMS key + GCS buckets (module data sources need existing resources).
resource "google_kms_key_ring" "gcp_read_only" {
  name     = "atlas-readonly-${random_string.suffix.id}"
  location = var.gcp_region
  project  = var.gcp_project_id
}

resource "google_kms_crypto_key" "gcp_read_only" {
  name     = "atlas-encryption-key"
  key_ring = google_kms_key_ring.gcp_read_only.id
  purpose  = "ENCRYPT_DECRYPT"
}

resource "google_storage_bucket" "gcp_read_only_backup" {
  name                        = "atlas-backup-readonly-${random_string.suffix.id}"
  location                    = var.gcp_region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_storage_bucket" "gcp_read_only_logs" {
  name                        = "atlas-logs-readonly-${random_string.suffix.id}"
  location                    = var.gcp_region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_kms_crypto_key_iam_member" "gcp_read_only_stand_in_atlas_encrypter" {
  crypto_key_id = google_kms_crypto_key.gcp_read_only.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${local.atlas_service_account_email_gcp_read_only}"
}

resource "google_kms_crypto_key_iam_member" "gcp_read_only_stand_in_atlas_viewer" {
  crypto_key_id = google_kms_crypto_key.gcp_read_only.id
  role          = "roles/cloudkms.viewer"
  member        = "serviceAccount:${local.atlas_service_account_email_gcp_read_only}"
}

resource "google_storage_bucket_iam_member" "gcp_read_only_stand_in_atlas_backup" {
  bucket = google_storage_bucket.gcp_read_only_backup.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${local.atlas_service_account_email_gcp_read_only}"
}

resource "google_storage_bucket_iam_member" "gcp_read_only_stand_in_atlas_logs" {
  bucket = google_storage_bucket.gcp_read_only_logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.atlas_service_account_email_gcp_read_only}"
}

resource "time_sleep" "gcp_read_only_atlas" {
  create_duration = "30s"
  depends_on = [
    google_kms_crypto_key_iam_member.gcp_read_only_stand_in_atlas_encrypter,
    google_kms_crypto_key_iam_member.gcp_read_only_stand_in_atlas_viewer,
    google_storage_bucket_iam_member.gcp_read_only_stand_in_atlas_backup,
    google_storage_bucket_iam_member.gcp_read_only_stand_in_atlas_logs,
  ]
}

locals {
  # tflint-ignore: terraform_unused_declarations
  kms_key_version_resource_id_gcp_read_only = google_kms_crypto_key.gcp_read_only.primary[0].name
  # tflint-ignore: terraform_unused_declarations
  backup_bucket_name_gcp_read_only = google_storage_bucket.gcp_read_only_backup.name
  # tflint-ignore: terraform_unused_declarations
  log_bucket_name_gcp_read_only = google_storage_bucket.gcp_read_only_logs.name
}

# Example module calls are generated in modules.generated.tf
