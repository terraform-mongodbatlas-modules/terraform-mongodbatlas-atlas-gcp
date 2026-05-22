## (Unreleased)

NOTES:

* provider/mongodbatlas: Requires minimum version 2.8.0 for mongodbatlas_log_integration support ([#35](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/35))

ENHANCEMENTS:

* example/log_integration: Adds log_integration example with MONGOD, MONGOS, and audit logs under separate prefix paths ([#36](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/36))
* module: Adds optional log_integration for Atlas GCS log export via mongodbatlas_log_integration ([#35](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/35))
* variable/timeouts: Adds nullable flat timeouts object with 30m defaults for module-managed Atlas and GCP resources, set `timeouts = null` for zero-diff upgrades from v0.x ([#38](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/pull/38))

## 0.1.0 (February 25, 2026)
* Initial release
