<!-- This file is used to generate the examples/README.md files -->
# {{ .NAME }}

<!-- BEGIN_GETTING_STARTED -->
## Prerequisites

If you are familiar with Terraform and already have a project configured in MongoDB Atlas, go to [commands](#commands).

To deploy MongoDB Atlas in GCP with Terraform, ensure you meet the following requirements:

1. Install [Terraform](https://developer.hashicorp.com/terraform/install) to be able to run `terraform` [commands](#commands).
2. [Sign in](https://account.mongodb.com/account/login) or [create](https://account.mongodb.com/account/register) your MongoDB Atlas Account.
3. Configure your [Atlas authentication](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs#authentication) method.

   **NOTE**: Service Accounts (SA) are the preferred authentication method. See [Grant Programmatic Access to an Organization](https://www.mongodb.com/docs/atlas/configure-api-access/#grant-programmatic-access-to-an-organization) in the MongoDB Atlas documentation for detailed instructions on configuring SA access to your project.

4. Configure your Google Cloud credentials using one of the [supported methods](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication).

   The following example uses [Application Default Credentials](https://docs.cloud.google.com/docs/authentication/application-default-credentials):

    ```sh
    gcloud auth application-default login
    ```

5. Use an existing [MongoDB Atlas project](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs/resources/project) or [create a new Atlas project resource](#optional-create-a-new-atlas-project-resource).
6. Install and configure the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install). 

   ```sh
   gcloud init
   ```

6. Authenticate your GCP session.

   ``` sh
   gcloud auth application-default login  
   ```

## Commands

The following `terraform` commands intiate, apply, and destroy your configuration:

```sh
terraform init # this will download the required providers and create a `terraform.lock.hcl` file.
# configure authentication env-vars (MONGODB_ATLAS_XXX, GOOGLE_APPLICATION_CREDENTIALS)
# configure your `vars.tfvars` with required variables
terraform apply -var-file vars.tfvars
# cleanup
terraform destroy -var-file vars.tfvars
```

## (Optional) Create a New Atlas Project Resource

Add the following code to the `main.tf` file to set your configuration in a new Atlas project:

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

{{ .CODE_SNIPPET }}
{{ .PRODUCTION_CONSIDERATIONS }}

## Feedback or Help

- If you have any feedback or trouble please open a Github Issue.
