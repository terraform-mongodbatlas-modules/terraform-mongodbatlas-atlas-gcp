# Testing Guide

Guide for running tests on the terraform-mongodbatlas-atlas-gcp module.

## Authentication Setup

```bash
# MongoDB Atlas
export MONGODB_ATLAS_CLIENT_ID=your_sa_client_id
export MONGODB_ATLAS_CLIENT_SECRET=your_sa_client_secret
export MONGODB_ATLAS_ORG_ID=your_org_id
export MONGODB_ATLAS_BASE_URL=https://cloud.mongodb.com/  # optional

# GCP (choose one)
gcloud auth application-default login                     # interactive login
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json   # service account key
```

See [MongoDB Atlas Provider Authentication](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs#authentication) and [Google Provider Authentication](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started#adding-credentials) for details.

## Test Commands

```bash
# Plan-only tests (no resources created)
just unit-plan-tests
```

## Version Compatibility Testing

```bash
just test-compat
```

Runs `terraform init` and `terraform validate` across all supported Terraform versions. Requires [mise](https://mise.jdx.dev/).

## Plan Snapshot Tests

Plan snapshot tests verify `terraform plan` output consistency. They use workspace directories under `tests/workspace_gcp_examples/`.

### Generating dev.tfvars

The `dev-vars-gcp` command reads from environment variables (see Authentication Setup above):

```bash
# Generate dev.tfvars from environment variables
just dev-vars-gcp
```

Optional env vars:
- `MONGODB_ATLAS_PROJECT_ID` - Use same project ID for all examples (plan snapshot reuse)
- `GCP_PROJECT_ID` (required) - GCP project for test resources

### Running Tests

```bash
# Run plan snapshot tests
just plan-snapshot-test-gcp
# If this fails and you want to update snapshots:
just ws-reg --force-regen

# Apply examples (creates real resources)
just apply-examples-gcp --auto-approve

# Check outputs
just ws-output-assertions

# Destroy resources after testing
just destroy-examples-gcp --auto-approve
```

### Snapshot Configuration

Configure examples in `tests/workspace_gcp_examples/workspace_test_config.yaml`:

```yaml
examples:
  - name: encryption
    var_groups: [encryption]
    plan_regressions:
      - address: module.atlas_gcp.module.encryption[0].mongodbatlas_encryption_at_rest.this
    output_assertions:
      - output: encryption
        not_empty: true
```

- **`var_groups`**: References variable sets defined in the same file under `var_groups:`. Each group maps variable names to module values.
- **`plan_regressions`**: Resource addresses to snapshot. Changes in plan output for these addresses cause test failures, catching unintended regressions.
- **`output_assertions`**: Validate module outputs after apply. Supports `not_empty`, `equals`, and `pattern` (regex) checks.

## Provider Dev Branch Testing

```bash
git clone https://github.com/mongodb/terraform-provider-mongodbatlas ../provider
just setup-provider-dev ../provider
export TF_CLI_CONFIG_FILE=$(pwd)/dev.tfrc
just unit-plan-tests
```

## CI Required Secrets

| Secret | Description |
|--------|-------------|
| `MONGODB_ATLAS_ORG_ID` | Atlas organization ID |
| `MONGODB_ATLAS_CLIENT_ID` | Service account client ID |
| `MONGODB_ATLAS_CLIENT_SECRET` | Service account client secret |
| `MONGODB_ATLAS_BASE_URL` | Atlas API base URL (optional, for cloud-dev) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload identity federation provider |
| `GCP_SERVICE_ACCOUNT_EMAIL` | GCP service account email |

| Variable | Description |
|----------|-------------|
| `GCP_PROJECT_ID` | GCP project for test resources |
