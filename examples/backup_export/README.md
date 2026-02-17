<!-- @generated
WARNING: This file is auto-generated. Do not edit directly.
Changes will be overwritten when documentation is regenerated.
Run 'just gen-examples' to regenerate.
-->
# GCS Bucket Export (Module-Managed)

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
module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  project_id = var.project_id

  backup_export = {
    enabled = true
    create_bucket = {
      enabled       = true
      name          = var.bucket_name
      name_suffix   = var.bucket_name_suffix
      location      = var.gcp_region
      force_destroy = var.force_destroy
    }
  }

  gcp_tags = var.gcp_tags
}

# Alternative: user-provided bucket (uncomment and remove create_bucket above)
# module "atlas_gcp" {
#   source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
#   project_id = var.project_id
#
#   backup_export = {
#     enabled     = true
#     bucket_name = "my-existing-bucket"
#   }
#
#   gcp_tags = var.gcp_tags
# }

output "backup_export" {
  value = module.atlas_gcp.backup_export
}

output "export_bucket_id" {
  value = module.atlas_gcp.export_bucket_id
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
