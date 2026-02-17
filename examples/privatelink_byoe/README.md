<!-- @generated
WARNING: This file is auto-generated. Do not edit directly.
Changes will be overwritten when documentation is regenerated.
Run 'just gen-examples' to regenerate.
-->
# BYOE (Bring Your Own Endpoint)

## Pre Requirements

If you are familiar with Terraform and already have a project configured in MongoDB Atlas go to [commands](#commands).

To use MongoDB Atlas through Terraform, ensure you meet the following requirements:

1. Install [Terraform](https://developer.hashicorp.com/terraform/install) to be able to run the `terraform` commands.
2. Sign up for a [MongoDB Atlas Account](https://www.mongodb.com/products/integrations/hashicorp-terraform).
3. Configure [authentication](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs#authentication).
4. [Create a new Atlas Project](#optionally-create-a-new-atlas-project-resource) to use with Terraform, or use an existing [MongoDB Atlas Project](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs/resources/project) by setting `project_id` in your `vars.tfvars` file.

## Commands

```sh
terraform init # this will download the required providers and create a `terraform.lock.hcl` file.
# configure authentication env-vars (MONGODB_ATLAS_XXX)
# configure your `vars.tfvars` with `project_id={PROJECT_ID}`
terraform apply -var-file vars.tfvars
# View all outputs
terraform output
# cleanup
terraform destroy -var-file vars.tfvars
```

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

## Optionally Create a New Atlas Project Resource

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

- You can use this and replace the `var.project_id` with `mongodbatlas_project.this.project_id` in the [main.tf](./main.tf) file.
