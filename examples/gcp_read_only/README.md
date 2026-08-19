<!-- @generated
WARNING: This file is auto-generated. Do not edit directly.
Changes will be overwritten when documentation is regenerated.
Run 'just gen-examples' to regenerate.
-->
# BYO CPA + Pre-Granted IAM

Uses an existing CPA and skip_iam_bindings for environments where Terraform cannot create GCP IAM bindings

<!-- BEGIN_GETTING_STARTED -->
## Prerequisites

If you are familiar with Terraform and already have a project configured in MongoDB Atlas, go to [commands](#commands).

To deploy MongoDB Atlas in GCP with Terraform, ensure you meet the following requirements:

1. Install [Terraform](https://developer.hashicorp.com/terraform/install) to be able to run `terraform` [commands](#commands).
2. [Sign in](https://account.mongodb.com/account/login) or [create](https://account.mongodb.com/account/register) your MongoDB Atlas Account.
3. Configure your [Atlas authentication](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs#authentication) method.

   **NOTE**: Service Accounts (SA) are the preferred authentication method. See [Grant Programmatic Access to an Organization](https://www.mongodb.com/docs/atlas/configure-api-access/#grant-programmatic-access-to-an-organization) in the MongoDB Atlas documentation for detailed instructions on configuring SA access to your project.

4. Install and configure the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install).

   ```sh
   gcloud init
   ```

   Authenticate in Google Cloud using one of the [supported methods](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication).

   The following example uses [Application Default Credentials](https://docs.cloud.google.com/docs/authentication/application-default-credentials):

   ```sh
   gcloud auth application-default login
   ```

5. Use an existing [MongoDB Atlas project](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs/resources/project) or [create a new Atlas project resource](#optional-create-a-new-atlas-project-resource).

## Commands

Use the following `terraform` commands to initiate, apply, or destroy your configuration:

```sh
terraform init # this will download the required providers and create a `terraform.lock.hcl` file.
# configure authentication env-vars (MONGODB_ATLAS_XXX, GOOGLE_APPLICATION_CREDENTIALS)
# configure your `vars.tfvars` with required variables
terraform apply -var-file vars.tfvars
# cleanup
terraform destroy -var-file vars.tfvars
```

## (Optional) Create a New Atlas Project Resource

To set your configuration in a new Atlas project, add the following code to the `main.tf` file:

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

Replace the `var.project_id` with `mongodbatlas_project.this.id` in the [main.tf](./main.tf) file.

<!-- END_GETTING_STARTED -->

## Code Snippet

Copy and use this code to get started quickly:

**main.tf**
```hcl
module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  project_id = var.project_id

  skip_iam_bindings = true

  cloud_provider_access = {
    create = false
    existing = {
      role_id                   = var.atlas_role_id
      service_account_for_atlas = var.atlas_service_account_email
    }
  }

  encryption = {
    enabled                 = true
    key_version_resource_id = var.kms_key_version_resource_id
  }

  backup_export = {
    enabled     = true
    bucket_name = var.backup_bucket_name
  }

  log_integration = {
    enabled     = true
    bucket_name = var.log_bucket_name
    integrations = [
      { log_types = ["MONGOD"], prefix_path = "operational/" },
      { log_types = ["MONGOD_AUDIT"], prefix_path = "audit/" },
    ]
  }
}

output "encryption_at_rest_provider" {
  value = module.atlas_gcp.encryption_at_rest_provider
}

output "encryption" {
  value = module.atlas_gcp.encryption
}

output "backup_export" {
  value = module.atlas_gcp.backup_export
}

output "export_bucket_id" {
  value = module.atlas_gcp.export_bucket_id
}

output "log_integration" {
  value = module.atlas_gcp.log_integration
}
```

**Additional files needed:**
- [variables.tf](./variables.tf)
- [versions.tf](./versions.tf)



## Feedback or Help

- If you have any feedback or found an error, open a GitHub Issue.
