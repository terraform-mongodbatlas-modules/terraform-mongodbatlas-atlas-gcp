# PrivateLink Topology Guide (GCP)

This guide helps you choose a Private Service Connect (PSC) layout for MongoDB Atlas on GCP. It maps four customer patterns to the GCP module variables and worked examples.

Your layout choice determines your application's reach to Atlas in case of region failure, your cost for cross-region data transfer, and connection string resilience when scaling to multiple regions. A single-region setup is simpler but leaves you with manual recovery if that region goes down. A multi-region setup adds resilience but requires one private endpoint for each cluster region and careful coordination of network resources in each app region with your Atlas connection strings. This guide helps you choose the right layout upfront.

A **Private Endpoint (PE)** is a private network path from your Virtual Private Cloud (VPC) to an Atlas cluster. **PSC** (Private Service Connect) is Google Cloud's PE technology. **PrivateLink** is the umbrella name MongoDB uses across cloud providers.

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Choose your outcome](#2-choose-your-outcome)
- [3. Pattern: Single region, same-region clients](#3-pattern-single-region-same-region-clients)
- [4. Pattern: Single region, cross-region clients](#4-pattern-single-region-cross-region-clients)
- [5. Pattern: Multi-region cluster, peered networks](#5-pattern-multi-region-cluster-peered-networks)
- [6. Pattern: Multi-region cluster, regional connection strings](#6-pattern-multi-region-cluster-regional-connection-strings)
- [7. Delivery option: BYO Endpoint](#7-delivery-option-byo-endpoint)
- [8. Operations and maintenance](#8-operations-and-maintenance)
- [9. Cluster and GCP module integration](#9-cluster-and-gcp-module-integration)
- [10. Alternatives to private endpoints](#10-alternatives-to-private-endpoints)
- [Appendix A: How it works](#appendix-a-how-it-works)
- [Glossary](#glossary)

## 1. Introduction

**Audience:** Teams configuring the GCP module who need a private network path from their applications to Atlas.

**Pre-reads (optional, for deeper context):**

- [Cluster topology guide](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-cluster/blob/main/docs/cluster_topology.md): how Atlas places replica nodes across regions.
- [Atlas: network security](https://www.mongodb.com/docs/atlas/architecture/current/network-security/), [high availability](https://www.mongodb.com/docs/atlas/architecture/current/high-availability/), [disaster recovery](https://www.mongodb.com/docs/atlas/architecture/current/disaster-recovery/).

**What this guide is not:** A replacement for the [Atlas private endpoint product docs](https://www.mongodb.com/docs/atlas/security-private-endpoint/) or for arch center disaster recovery (DR) design. PrivateLink layout does not protect against a **GCP-wide** outage. For provider-wide failure, use [arch center disaster recovery](https://www.mongodb.com/docs/atlas/architecture/current/disaster-recovery/) and [multi-cloud distribution](https://www.mongodb.com/docs/atlas/cluster-config/multi-cloud-distribution/) where needed. Use the module README for variable reference; use this guide to pick a pattern.

## 2. Choose your outcome

### 2.1 What you're optimizing for

High Availability (HA) is automatic recovery. Disaster Recovery (DR) is manual recovery from a cross-region backup. DR is available regardless of PrivateLink layout and is not covered by this guide.

- **Zonal HA:** Tolerate a single-zone failure. Atlas covers this by default with multi-zone replica sets. No PrivateLink work needed.
- **Regional HA:** Tolerate an Atlas region outage with no human action. Opt-in via a multi-region cluster: electable nodes in two or more regions, and the driver fails over automatically. This drives [Q1](#22-decision-which-pattern-fits) and changes the PrivateLink layout because Atlas needs one private endpoint per cluster region. Without regional HA, an Atlas region outage falls back to DR (manual restore from a cross-region backup).
- **Multi-region applications:** Where your application tier runs. One region, several regions of the same VPC, or several VPCs across regions. This drives [Q2](#22-decision-which-pattern-fits) and is independent of regional HA. Application-tier resilience to a client region outage falls out of this choice; see **Resilience** in each pattern below.
- **Cost:** Fewer endpoints, fewer cross-region data flows, smaller dev setups.
- **Portability:** Avoid GCP-specific options that block multi-cloud or migration later. On a multi-cloud Atlas cluster, a GCP private endpoint reaches only nodes Atlas runs in GCP. Use VPN or a secondary read preference for nodes in other clouds. See [Atlas multi-cloud distribution](https://www.mongodb.com/docs/atlas/cluster-config/multi-cloud-distribution/).
- **Private connectivity and GCP resource ownership:** Compare PrivateLink to VPC peering and public IP in [section 10](#10-alternatives-to-private-endpoints). For who creates GCP consumer endpoints (module-managed or BYO Endpoint), see [section 7](#7-delivery-option-byo-endpoint).

### 2.2 Decision: which pattern fits

Two questions, in order:

**Q1. Do you need regional HA (automatic regional failover)?**

- **No** → single-region cluster. An Atlas region outage falls back to DR (manual restore from a cross-region backup).
- **Yes** → multi-region cluster (Atlas needs one PE per cluster region).

**Q2. Do all your application VPCs sit in the same region as the cluster?**

- **Yes** → same-region clients.
- **No, but the VPCs in other regions can peer to the cluster region's VPC** → cross-region clients (single-region cluster) or peered networks (multi-region cluster).
- **No, and they cannot peer cross-region** → regional connection strings (multi-region cluster only; sharded clusters only).

| Q1 regional HA | Q2 application regions | Pattern |
| --- | --- | --- |
| No | Same region as cluster | [Single region, same-region clients](#3-pattern-single-region-same-region-clients) |
| No | Other regions, peered | [Single region, cross-region clients](#4-pattern-single-region-cross-region-clients) |
| Yes | All regions reachable via peering | [Multi-region, peered networks](#5-pattern-multi-region-cluster-peered-networks) |
| Yes | App regions cannot peer to all cluster regions | [Multi-region, regional connection strings](#6-pattern-multi-region-cluster-regional-connection-strings) |

For deeper background on Atlas regional outage tolerance, see [Atlas high availability](https://www.mongodb.com/docs/atlas/architecture/current/high-availability/) and [Atlas disaster recovery](https://www.mongodb.com/docs/atlas/architecture/current/disaster-recovery/).

## 3. Pattern: Single region, same-region clients

**In one line:** One Atlas region, one private endpoint, applications in the same region.

**Requirements**

- Production workload with a private-only network policy and a single primary region.
- Manual recovery acceptable if the cluster region goes down (region add, restore, or temporary public-IP fallback).
- Consumer applications in the cluster region (or VPCs peered into that region's VPC).

**Resilience**

- **Cluster region:** Total outage until manual DR.
- **Client region:** Not applicable (apps colocate with the cluster).

**Multi-VPC variation:** When several consumer VPCs in the same region need their own endpoints to the same cluster, use [`privatelink_endpoints_single_region`](../README.md#privatelink_endpoints_single_region) instead of [`privatelink_endpoints`](../README.md#privatelink_endpoints).

**Replica-set constraint:** Atlas allows at most one PE per region for replica-set clusters. If you need multiple consumer endpoints in one region against a replica set, you must move to a sharded cluster.

**Module configuration:**

```hcl
module "atlas_gcp" {
  source     = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version    = "~> 0.2"
  project_id = var.project_id

  privatelink_endpoints = [{
    region     = "us-east4"
    subnetwork = var.subnetwork
  }]
}
```

Worked example: [`examples/privatelink`](../examples/privatelink).

**Cost note:** One endpoint hourly charge; no cross-region egress.

## 4. Pattern: Single region, cross-region clients

**In one line:** One Atlas region; applications run in several GCP regions of the same VPC and reach the endpoint through PSC global access.

**Requirements**

- Same as [Pattern 3](#3-pattern-single-region-same-region-clients), but applications run in multiple GCP regions of the same VPC.
- Apps in healthy regions must keep serving when one client region fails.

**Resilience**

- **Cluster region:** Total outage until manual DR.
- **Client region:** Apps in healthy regions keep serving; apps in a client region that loses all paths to the cluster region go offline.

**Module configuration:** Set `all_region_mode = true` on the endpoint object so the GCP forwarding rule accepts traffic from clients in other regions of the same VPC.

```hcl
module "atlas_gcp" {
  source     = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version    = "~> 0.2"
  project_id = var.project_id

  privatelink_endpoints = [{
    region          = "us-east4"
    subnetwork      = var.subnetwork
    all_region_mode = true
  }]
}
```

Worked example: [`examples/privatelink`](../examples/privatelink) (set `all_region_mode = true` as in the snippet above).

**Cost note:** One endpoint hourly charge; you pay GCP cross-region VPC egress for client-to-cluster traffic.

`all_region_mode` is a GCP-level switch on the consumer side. It is not the same as the Atlas project setting [`privatelink_regional_mode`](../README.md#privatelink_regional_mode); see [Appendix A.3](#a3-two-gcp-knobs-not-to-confuse) for the contrast.

## 5. Pattern: Multi-region cluster, peered networks

**In one line:** The Atlas cluster has electable nodes in two or more regions; one private endpoint per cluster region; all application VPCs can reach every endpoint subnet via peering.

**Requirements**

- Regional HA for the cluster (electable nodes in two or more regions).
- Full routing mesh: every application VPC can reach every cluster region PE subnet (peering, VPN, or equivalent).

**Resilience**

- **Cluster region:** Driver fails over via one global connection string when the routing mesh is intact; any unreachable app-to-cluster region pair blocks access to nodes in that region.
- **Client region:** Only apps in the failed client region go offline.

**Module configuration:** Provide one entry in [`privatelink_endpoints`](../README.md#privatelink_endpoints) per cluster region. Leave [`privatelink_regional_mode`](../README.md#privatelink_regional_mode) at its default (off).

```hcl
module "atlas_gcp" {
  source     = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version    = "~> 0.2"
  project_id = var.project_id

  privatelink_endpoints = [
    { region = "us-east4",  subnetwork = var.subnetwork_useast4 },
    { region = "us-west1",  subnetwork = var.subnetwork_uswest1 },
  ]
}
```

Worked example: [`examples/privatelink`](../examples/privatelink) (multi-region endpoints; leave `privatelink_regional_mode` at its default).

**Cost note:** One endpoint per cluster region; cross-region peering cost is on the customer side.

## 6. Pattern: Multi-region cluster, regional connection strings

**In one line:** Multi-region cluster, but application networks cannot peer cross-region; each region's apps use a connection string scoped to that region.

**Requirements**

- Regional HA for the cluster.
- Application VPCs in different regions cannot peer cross-region.
- Sharded or geo-sharded clusters only (replica sets cannot use this pattern).

**Resilience**

- **Cluster region:** That region's connection string stops resolving; other regions keep working via their own URI. Cross-region failover from the application's view requires app-side logic (each app is pinned to one region's URI).
- **Client region:** Only apps in the failed client region go offline.

**Module configuration:** Set [`privatelink_regional_mode`](../README.md#privatelink_regional_mode) to `"auto"`. The Atlas project then emits one connection string per cluster region.

```hcl
module "atlas_gcp" {
  source     = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version    = "~> 0.2"
  project_id = var.project_id

  privatelink_endpoints = [
    { region = "us-east4",  subnetwork = var.subnetwork_useast4 },
    { region = "us-west1",  subnetwork = var.subnetwork_uswest1 },
  ]
  privatelink_regional_mode = "auto"
}
```

Worked example: [`examples/privatelink`](../examples/privatelink) (set `privatelink_regional_mode = "auto"` as in the snippet above).

**Cost note:** One endpoint per cluster region; no cross-region application traffic since each app stays regional.

`privatelink_regional_mode` is an Atlas project setting. See [Appendix A.3](#a3-two-gcp-knobs-not-to-confuse) for how it differs from `all_region_mode`. Toggling it later regenerates connection strings for the whole project; plan a maintenance window.

## 7. Delivery option: BYO Endpoint

**BYO Endpoint** (Bring Your Own Endpoint) is a delivery mode that applies on top of any of [patterns 3 through 6](#2-choose-your-outcome). It does not change the topology; it changes who owns the GCP forwarding rule. For product background, see [Atlas: Learn About Private Endpoints](https://www.mongodb.com/docs/atlas/security-private-endpoint/). For module variables and a worked config, see the [module README](../README.md#privatelink_byo_endpoint) and [`examples/privatelink_byoe`](../examples/privatelink_byoe).

| Mode | Who creates the GCP forwarding rule | Apply cycle |
| --- | --- | --- |
| **Module-managed (default)** | The GCP module. | One `terraform apply`. |
| **BYO Endpoint** | You, outside the module. | Two-phase workflow: (1) the module creates the Atlas service; (2) the module links your forwarding rule to the Atlas endpoint. |

**Choose BYO Endpoint when:**

- Your IAM policy denies the GCP module the rights to create forwarding rules.
- Existing network automation already owns the consumer endpoints.
- You need GCP resource settings the module does not expose on forwarding rules or addresses.

**Trade-off:** Multi-phase apply adds operator work compared with module-managed endpoints. Pick BYO Endpoint only when constraints force it.

**Module configuration:** Use [`privatelink_byo_endpoint`](../README.md#privatelink_byo_endpoint) for the Atlas service and [`privatelink_byo_service`](../README.md#privatelink_byo_service) for Atlas registration, with your GCP resources in between. Both module steps can run in one `terraform apply` when your root module also declares the forwarding rule. Worked example: [`examples/privatelink_byoe`](../examples/privatelink_byoe).

## 8. Operations and maintenance

Plan for application-side disruption when any of these happen:

- **Replica set converted to sharded:** Connection string targets change; applications restart.
- **`privatelink_regional_mode` toggled:** Sharded connection strings regenerate project-wide; plan a window.
- **Cluster region added or removed:** Atlas may regenerate DNS records when the connection string shape changes. If you add a cluster region without a matching private endpoint already in place, Atlas disables PrivateLink for the entire cluster until you add that endpoint or remove the new region. Add the endpoint **before** you add electable nodes in the new region.
- **Endpoint removed during cluster maintenance:** Multi-region clusters require the endpoint to stay during maintenance windows. See the [Atlas private endpoint docs](https://www.mongodb.com/docs/atlas/security-private-endpoint/).

## 9. Cluster and GCP module integration

PrivateLink configuration splits across two modules in the same Atlas project:

- **`module.atlas_gcp`**: Creates Atlas private endpoint services and GCP consumer endpoints (or registers BYO forwarding rules).
- **`module.cluster`**: Defines cluster topology. Atlas emits private connection strings from both.

Share the same `project_id` on both modules. Atlas requires one private endpoint service per electable cluster region, so each region in the cluster module's `regions` list needs a matching entry in `privatelink_endpoints` (or the BYO equivalent).

Set `depends_on = [module.atlas_gcp]` on the cluster module to ensure private endpoints are ready before creating the cluster.

Pattern-specific variable choices are in [sections 3–7](#3-pattern-single-region-same-region-clients). The [module README](../README.md#private-service-connect) and [`examples/`](../examples/) directory hold full variable reference and worked configs.

### Basic example

Single-region replica set with one module-managed endpoint:

```hcl
module "atlas_gcp" {
  source     = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version    = "~> 0.2"
  project_id = var.project_id

  privatelink_endpoints = [{
    region     = "us-east4"
    subnetwork = var.subnetwork
  }]
}

module "cluster" {
  source       = "terraform-mongodbatlas-modules/cluster/mongodbatlas"
  project_id   = var.project_id
  name         = "app-data"
  cluster_type = "REPLICASET"

  regions = [{
    name          = "US_EAST_4"
    provider_name = "GCP"
    node_count    = 3
  }]

  depends_on = [module.atlas_gcp] # Ensures private endpoints are ready before creating the cluster
}
```

The cluster module uses Atlas region names (`US_EAST_4`); the GCP module accepts GCP format (`us-east4`) or Atlas format (`US_EAST_4`) on input. Module-managed `privatelink_endpoints` keys normalize to GCP format in Terraform state.

For multi-region layouts, add one endpoint per cluster region and set `privatelink_regional_mode = "auto"` when applications need per-region connection strings ([Pattern 6](#6-pattern-multi-region-cluster-regional-connection-strings)).

## 10. Alternatives to private endpoints

If you have not committed to PrivateLink yet, a private endpoint is one of three ways to keep cluster traffic off the public internet.

| Mechanism | When to choose | When to avoid |
| --- | --- | --- |
| **PrivateLink (PSC)** | Regulatory requirement; private-only network policy; production. | Lower environments without a security mandate. |
| **VPC peering only** | Single cloud provider; simpler; lower cost. | Multi-cloud; regulated multi-VPC. |
| **Public IP + access list** | Dev/test; low risk; quick setup. | Production with a private-only mandate. |

## Appendix A: How it works

This section explains the Atlas and GCP mechanics behind the patterns. Skip it if you only need to pick a pattern.

### A.1 What the driver connects to

A MongoDB driver opens connections to the cluster's nodes using a connection string Atlas generates. Two cluster shapes drive different connection-string behavior:

- **Replica set:** The driver opens connections to the data-bearing processes in every cluster region. Each region therefore needs its own private endpoint.
- **Sharded or geo-sharded:** The driver opens connections only to the cluster's query routers, not to individual shards. The query routers exist per region; Atlas can emit one global connection string (when application networks can peer) or one connection string per region (when they cannot).

### A.2 The three layers

1. **Cluster topology layer (Atlas).** The cluster's electable regions decide where Atlas runs data nodes. This is configured in the cluster module, not the GCP module.
2. **Atlas private-endpoint layer.** For each cluster region, Atlas exposes a *private endpoint service*. The Atlas project setting `privatelink_regional_mode` controls whether sharded clusters publish one global connection string or one per region.
3. **GCP consumer layer.** This is what the GCP module manages: a PSC forwarding rule and internal IP that points at the Atlas private endpoint service. `all_region_mode` is the GCP-side switch that lets clients in other regions of the same VPC use this consumer endpoint.

The application driver sees the cluster through layers 2 and 3.

### A.3 Two GCP knobs not to confuse

`all_region_mode` and `privatelink_regional_mode` look similar but operate at different layers:

- **[`all_region_mode`](../README.md#privatelink_endpoints):** Set per endpoint object. Configures the GCP PSC forwarding rule to accept traffic from clients in other regions of the same VPC. Used by [Pattern 4](#4-pattern-single-region-cross-region-clients).
- **[`privatelink_regional_mode`](../README.md#privatelink_regional_mode):** Atlas project-level setting. Switches sharded clusters from one global connection string to one connection string per region. Used by [Pattern 6](#6-pattern-multi-region-cluster-regional-connection-strings).

You can set both at once. They do not replace each other.

### A.4 PSC forwarding-rule details

GCP PSC uses one forwarding rule per Atlas service region. Atlas multiplexes shard traffic on that rule by mapping cluster ports internally; this is the "port-mapped PSC" architecture. Connection strings use `psc-*` hostnames on GCP. AWS and Azure still use the legacy `pl-*` format. Older GCP integrations also used `pl-*`; that form is deprecated on GCP and this module does not use it.

## Glossary

- **all_region_mode:** Module input on a `privatelink_endpoints` entry that enables PSC global access on the GCP forwarding rule.
- **BYO Endpoint (Bring Your Own Endpoint):** Delivery mode where the customer creates the GCP forwarding rule outside the module. See [section 7](#7-delivery-option-byo-endpoint).
- **Connection string:** The URI a MongoDB driver uses to connect to a cluster. Atlas generates one global connection string by default; `privatelink_regional_mode` switches sharded clusters to one connection string per region.
- **Disaster Recovery (DR):** Manual recovery from a regional or larger failure, typically by restoring from a cross-region backup. Always available regardless of PrivateLink layout.
- **High Availability (HA):** Automatic recovery with no human action. **Zonal HA** is on by default for any Atlas cluster (multi-zone replica set). **Regional HA** is opt-in via a multi-region cluster.
- **PE / Private Endpoint:** A private network path from a customer VPC to an Atlas cluster.
- **PSC / Private Service Connect:** Google Cloud's PE technology.
- **PrivateLink:** Umbrella name MongoDB uses for PE features across cloud providers. The Atlas terraform variable namespace uses `privatelink_*`.
- **privatelink_regional_mode:** Atlas project setting that controls whether sharded clusters publish one global or per-region connection string.
- **VPC (Virtual Private Cloud):** Customer-side private network where applications and PSC consumer endpoints live.

## Additional resources

- [Module README](../README.md#private-service-connect)
- [v0.2.0 upgrade guide](v0.2.0-upgrade-guide.md)
- [Atlas: Learn About Private Endpoints](https://www.mongodb.com/docs/atlas/security-private-endpoint/)
- [Cluster topology guide](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-cluster/blob/main/docs/cluster_topology.md)
- [Google PSC + MongoDB codelab (uses legacy `port_mapping_enabled = false`)](https://codelabs.developers.google.com/codelabs/psc-mongo-globalaccess)
