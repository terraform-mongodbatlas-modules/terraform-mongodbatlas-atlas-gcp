<!-- @generated
WARNING: This file is auto-generated. Do not edit directly.
Changes will be overwritten when documentation is regenerated.
Run 'just gen-examples' to regenerate.
-->
# BYOE (Bring Your Own Endpoint)

<!-- BEGIN_GETTING_STARTED -->
## Prerequisites

If you are familiar with Terraform and already have a project configured in MongoDB Atlas, go to [commands](#commands).

To deploy MongoDB Atlas in GCP with Terraform, ensure you meet the following requirements:

1. Install [Terraform](https://developer.hashicorp.com/terraform/install) to be able to run `terraform` [commands](#commands).
2. [Sign in](https://account.mongodb.com/account/login) or [create](https://account.mongodb.com/account/register) your MongoDB Atlas Account.
3. Configure your [authentication](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs#authentication) method.

   **NOTE**: Service Accounts (SA) are the preferred authentication method. See [Grant Programmatic Access to an Organization](https://www.mongodb.com/docs/atlas/configure-api-access/#grant-programmatic-access-to-an-organization) in the MongoDB Atlas documentation for detailed instructions on configuring SA access to your project.

4. Use an existing [MongoDB Atlas project](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs/resources/project) or [create a new Atlas project resource](#optional-create-a-new-atlas-project-resource).
5. Install and configure the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (`gcloud init`) and authenticate your session.

## Commands

```sh
terraform init # this will download the required providers and create a `terraform.lock.hcl` file.
# configure authentication env-vars (MONGODB_ATLAS_XXX, GOOGLE_APPLICATION_CREDENTIALS)
# configure your `vars.tfvars` with required variables
terraform apply -var-file vars.tfvars
# cleanup
terraform destroy -var-file vars.tfvars
```

## (Optional) Create a New Atlas Project Resource

```hcl
variable "org_id" {
  type    = string
  default = "{ORG_ID}" # REPLACE with your organization id, for example `65def6ce0f722a1507105aa5`.
}

resource "mongodbatlas_project" "this" {
  name   = "cluster-module"
  org_id = var.org_id
}
```

- Replace the `var.project_id` with `mongodbatlas_project.this.id` in the [main.tf](./main.tf) file.

<!-- END_GETTING_STARTED -->

## Code Snippet

Copy and use this code to get started quickly:

**main.tf**
```hcl
/*
  BYOE (Bring Your Own Endpoint) pattern for GCP Private Service Connect.

  Single `terraform apply` approach:
  1. Create Atlas-side PrivateLink using `privatelink_byoe_regions` to get service attachment info.
  2. Create your own GCP address + forwarding rule using `privatelink_service_info` output.
  3. Register your endpoint with Atlas using `privatelink_byoe` to complete the connection.
*/

locals {
  ep1 = "ep1"
}

module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  project_id = var.project_id

  privatelink_byoe = {
    (local.ep1) = {
      ip_address           = google_compute_address.psc.address
      forwarding_rule_name = google_compute_forwarding_rule.psc.name
      # gcp_project_id     = "my-other-project" # optional: override when forwarding rule is in a different GCP project
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

# privatelink -- connection status after BYOE registration
output "privatelink" {
  description = "PrivateLink connection details"
  value       = module.atlas_gcp.privatelink[local.ep1]
}

output "forwarding_rule_id" {
  description = "GCP forwarding rule ID"
  value       = google_compute_forwarding_rule.psc.id
}
```

**Additional files needed:**
- [variables.tf](./variables.tf)
- [versions.tf](./versions.tf)



## Feedback or Help

- If you have any feedback or trouble please open a Github Issue.
