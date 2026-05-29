## (Unreleased)

## 0.2.0 (May 29, 2026)

BREAKING CHANGES:

* module: Normalizes module-managed multi-region PrivateLink endpoint for_each keys to lowercase GCP region format ([#40](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/40))
* variable/backup_export: Renames create_bucket to create_gcs_bucket ([#37](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/37))
* variable/create_gcs_bucket: Changes versioning_enabled default to false on backup_export and log_integration module-managed GCS buckets ([#37](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/37))
* variable/privatelink_byo_endpoint: Renames privatelink_byoe_regions to privatelink_byo_endpoint and changes type to map(object({ region = string })) ([#40](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/40))
* variable/privatelink_byo_service: Renames privatelink_byoe to privatelink_byo_service ([#40](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/40))
* variable/privatelink_regional_mode: Makes private endpoint regional mode opt-in with default disabled ([#43](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/43))

NOTES:

* provider/mongodbatlas: Requires minimum version 2.8.0 for mongodbatlas_log_integration support ([#35](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/35))

ENHANCEMENTS:

* example/gcp_read_only: Adds read-only GCP example with BYO CPA and pre-granted IAM ([#39](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/39))
* example/log_integration: Adds log_integration example with MONGOD, MONGOS, and audit logs under separate prefix paths ([#36](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/36))
* module: Adds optional log_integration for Atlas GCS log export via mongodbatlas_log_integration ([#35](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/35))
* output/backup_export: Adds expiration_days to backup_export output ([#37](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/37))
* variable/backup_export: Adds optional expiration_days lifecycle on module-managed GCS buckets ([#37](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/37))
* variable/privatelink_endpoints: Adds optional all_region_mode on module-managed PSC forwarding rules ([#43](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/43))
* variable/skip_iam_bindings: Adds skip flag to omit module-managed GCP IAM bindings when roles are pre-granted externally ([#39](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/39))
* variable/timeouts: Adds nullable flat timeouts object with 30m defaults for module-managed Atlas and GCP resources, set `timeouts = null` for zero-diff upgrades from v0.x ([#38](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/38))

BUG FIXES:

* submodule/backup_export: Grants roles/storage.objectUser instead of roles/storage.objectCreator for snapshot export ([#37](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/37))

## 0.1.0 (February 25, 2026)
* Initial release
