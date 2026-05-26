# PrivateLink Topology Guide (GCP)

This guide helps you choose a Private Service Connect (PSC) layout for MongoDB Atlas on GCP. It maps four customer patterns to the GCP module variables and worked examples.

A **Private Endpoint (PE)** is a private network path from your Virtual Private Cloud (VPC) to an Atlas cluster. **PSC** (Private Service Connect) is Google Cloud's PE technology. **PrivateLink** is the umbrella name MongoDB uses across cloud providers.

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Choose your outcome](#2-choose-your-outcome)
- [3. Pattern: Single region, same-region clients](#3-pattern-single-region-same-region-clients)
- [4. Pattern: Single region, cross-region clients](#4-pattern-single-region-cross-region-clients)
- [5. Pattern: Multi-region cluster, peered networks](#5-pattern-multi-region-cluster-peered-networks)
- [6. Pattern: Multi-region cluster, regional connection strings](#6-pattern-multi-region-cluster-regional-connection-strings)
- [7. Delivery option: BYO Endpoint](#7-delivery-option-byo-endpoint)
- [8. Operations and failure modes](#8-operations-and-failure-modes)
- [9. Cost and environment guidance](#9-cost-and-environment-guidance)
- [10. GCP module configuration](#10-gcp-module-configuration)
- [Appendix A: How it works](#appendix-a-how-it-works)
- [Glossary](#glossary)

## 1. Introduction

**Audience:** Teams configuring the GCP module who need a private network path from their applications to Atlas.

**Pre-reads (optional, for deeper context):**

- [Cluster topology guide](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-cluster/blob/main/docs/cluster_topology.md): how Atlas places replica nodes across regions.
- [Atlas: network security](https://www.mongodb.com/docs/atlas/architecture/current/network-security/), [high availability](https://www.mongodb.com/docs/atlas/architecture/current/high-availability/), [disaster recovery](https://www.mongodb.com/docs/atlas/architecture/current/disaster-recovery/).

**What this guide is not:** A replacement for the [Atlas private endpoint product docs](https://www.mongodb.com/docs/atlas/security-private-endpoint/) or for arch center disaster recovery (DR) design. Use the module README for variable reference; use this guide to pick a pattern.

## 2. Choose your outcome

### 2.1 What you're optimizing for

High Availability (HA) is automatic recovery. Disaster Recovery (DR) is manual recovery from a cross-region backup; it is always available regardless of PrivateLink layout, so this guide does not configure it.

- **Zonal HA:** Tolerate a single-zone failure. Atlas covers this by default with multi-zone replica sets. No PrivateLink work needed.
- **Regional HA:** Tolerate an Atlas region outage with no human action. Opt-in via a multi-region cluster: electable nodes in two or more regions, and the driver fails over automatically. This drives [Q1](#23-decision-which-pattern-fits) and changes the PrivateLink layout because Atlas needs one private endpoint per cluster region. Without regional HA, an Atlas region outage falls back to DR (manual restore from a cross-region backup).
- **Multi-region applications:** Where your application tier runs. One region, several regions of the same VPC, or several VPCs across regions. This drives [Q2](#23-decision-which-pattern-fits) and is independent of regional HA. Application-tier resilience to a client region outage falls out of this choice; see the failure tables in each pattern card and [section 8](#8-operations-and-failure-modes).
- **Cost:** Fewer endpoints, fewer cross-region data flows, smaller dev setups.
- **Portability:** Avoid GCP-specific options that block multi-cloud or migration later.

### 2.2 Alternatives to private endpoints

A private endpoint is one of three ways to keep cluster traffic off the public internet. Pick PrivateLink only if you need it.

| Mechanism | When to choose | When to avoid |
| --- | --- | --- |
| **PrivateLink (PSC)** | Regulatory requirement; private-only network policy; production. | Lower environments without a security mandate. |
| **VPC peering only** | Single cloud provider; simpler; lower cost. | Multi-cloud; regulated multi-VPC. |
| **Public IP + access list** | Dev/test; low risk; quick setup. | Production with a private-only mandate. |

The **BYO Endpoint** (Bring Your Own Endpoint) option in [section 7](#7-delivery-option-byo-endpoint) is a delivery mode for PrivateLink, not an alternative to it.

### 2.3 Decision: which pattern fits

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

**When to choose:**

- Production workload with a private-only network policy and a single primary region.
- You accept manual recovery if the cluster region goes down (region add, restore from backup, or temporary public-IP fallback).
- All consumer applications live in the cluster's region (or in VPCs peered into that region's VPC).

**Survives:**

- Single-zone failure: yes (Atlas multi-zone replica election).
- Cluster region outage: no. Manual DR required.
- Client region outage: not applicable (apps are in the cluster region).

**Doesn't survive:**

- A GCP regional outage takes the cluster offline until you act.
- Removing the endpoint during a cluster maintenance window causes downtime.

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

**When to choose:**

- Same constraints as [Pattern 3](#3-pattern-single-region-same-region-clients), but apps run in multiple GCP regions of the same VPC.
- You want apps in healthy regions to keep serving when one client region fails.
- You still accept manual DR for a cluster region outage.

**Survives:**

- Single-zone failure: yes.
- Cluster region outage: no. Manual DR required (the cluster lives in one region).
- Client region outage: yes for apps in healthy regions; the endpoint stays reachable from any peered region.

**Doesn't survive:**

- The cluster region itself going down.
- A consumer region whose apps lose all peering paths to the cluster region.

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

Worked example: [`examples/privatelink_global_access`](../examples/privatelink_global_access).

**Cost note:** One endpoint hourly charge; you pay GCP cross-region VPC egress for client-to-cluster traffic.

`all_region_mode` is a GCP-level switch on the consumer side. It is not the same as the Atlas project setting [`privatelink_regional_mode`](../README.md#privatelink_regional_mode); see [Appendix A.3](#a3-two-gcp-knobs-not-to-confuse) for the contrast.

## 5. Pattern: Multi-region cluster, peered networks

**In one line:** The Atlas cluster has electable nodes in two or more regions; one private endpoint per cluster region; all application VPCs can reach every endpoint subnet via peering.

**When to choose:**

- You need regional HA (automatic regional failover) for the cluster.
- Your network team can peer (or VPN, or otherwise route) every application VPC to every cluster region's PE subnet.
- Works for both replica-set and sharded clusters.

**Survives:**

- Single-zone failure: yes.
- Cluster region outage: yes; the driver fails over to a healthy region using a single global connection string.
- Client region outage: only the apps in the failed region go offline. Apps in healthy client regions keep serving.

**Doesn't survive:**

- A scenario where one application region cannot reach one cluster region (driver loses access to that node).
- Removing a private endpoint during cluster maintenance.

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

Worked example: see [`examples/privatelink_multi_region`](../examples/privatelink_multi_region) and remove `privatelink_regional_mode = "auto"` for this pattern.

**Cost note:** One endpoint per cluster region; cross-region peering cost is on the customer side.

## 6. Pattern: Multi-region cluster, regional connection strings

**In one line:** Multi-region cluster, but application networks cannot peer cross-region; each region's apps use a connection string scoped to that region.

**When to choose:**

- You need regional HA (automatic regional failover) for the cluster.
- Application VPCs in different regions cannot peer to each other (regulatory, organizational, or routing constraints).
- Sharded or geo-sharded clusters only. Replica sets cannot use this pattern.

**Survives:**

- Single-zone failure: yes.
- Cluster region outage: the failed region's connection string stops resolving; apps in other regions keep working through their own region-scoped connection string. Cross-region failover requires application-side logic.
- Client region outage: only the apps in the failed client region go offline.

**Doesn't survive:**

- Cluster-side automatic failover from the *application's* point of view: each app is pinned to one region's connection string.
- Replica-set clusters (the pattern is sharded-only).

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

Worked example: [`examples/privatelink_multi_region`](../examples/privatelink_multi_region).

**Cost note:** One endpoint per cluster region; no cross-region application traffic since each app stays regional.

`privatelink_regional_mode` is an Atlas project setting. See [Appendix A.3](#a3-two-gcp-knobs-not-to-confuse) for how it differs from `all_region_mode`. Toggling it later regenerates connection strings for the whole project; plan a maintenance window.

## 7. Delivery option: BYO Endpoint

**BYO Endpoint** (Bring Your Own Endpoint) is a delivery mode that applies on top of any of [patterns 3 through 6](#2-choose-your-outcome). It does not change the topology; it changes who owns the GCP forwarding rule.

| Mode | Who creates the GCP forwarding rule | Apply cycle |
| --- | --- | --- |
| **Module-managed (default)** | The GCP module. | One `terraform apply`. |
| **BYO Endpoint** | You, outside the module. | Two-phase: phase 1 reserves the Atlas service; phase 2 registers the customer-created endpoint with Atlas. |

**Choose BYO Endpoint when:**

- Your IAM policy denies the GCP module the rights to create forwarding rules.
- Existing network automation already owns the consumer endpoints.
- You need to set GCP-side flags before registration (for example `--allow-psc-global-access` for cross-region clients).

**Trade-off:** Two-phase apply doubles the operator work compared with module-managed endpoints. Pick BYO Endpoint only when constraints force it.

**Module configuration:** Use [`privatelink_byo_endpoint`](../README.md#privatelink_byo_endpoint) (phase 1) and [`privatelink_byo_service`](../README.md#privatelink_byo_service) (phase 2). Worked example: [`examples/privatelink_byoe`](../examples/privatelink_byoe).

## 8. Operations and failure modes

### 8.1 Failure mode reference

| Failure | Pattern 3 | Pattern 4 | Pattern 5 | Pattern 6 |
| --- | --- | --- | --- | --- |
| Single-zone failure | Auto | Auto | Auto | Auto |
| Cluster region outage | Total outage; manual DR | Total outage; manual DR | Driver fails over via global URI | Failed region's URI stops; other regions keep working |
| Client region outage | Apps in that region offline | Apps in healthy client regions keep serving | Only apps in failed region offline | Only apps in failed region offline |
| PE removed during cluster maintenance | Downtime | Downtime | Downtime | Downtime |

Two scope notes:

- **Multi-cloud cluster + PrivateLink:** A GCP private endpoint reaches only the cluster nodes that Atlas runs on GCP. Use VPN or a secondary read preference for nodes in other clouds. See [Atlas multi-cloud distribution](https://www.mongodb.com/docs/atlas/cluster-config/multi-cloud-distribution/).
- **GCP-wide outage:** PrivateLink does not help here. This is the territory of multi-cloud topology.

### 8.2 Change events that force a reconnect or a window

Plan for application-side disruption when any of these happen:

- **Replica set converted to sharded:** Connection string targets change; applications restart.
- **`privatelink_regional_mode` toggled:** Sharded connection strings regenerate project-wide; plan a window.
- **Cluster region added or removed:** Atlas regenerates DNS records; applications reconnect if the connection string shape changes.
- **Endpoint removed during cluster maintenance:** Multi-region clusters require the endpoint to stay during maintenance windows. See the [Atlas private endpoint docs](https://www.mongodb.com/docs/atlas/security-private-endpoint/).

## 9. Cost and environment guidance

**Cost drivers (cloud-neutral):**

- Per-endpoint hourly charge from the cloud provider.
- Atlas private endpoint billing per service. See [Atlas private endpoint billing](https://www.mongodb.com/docs/atlas/billing/additional-services/#std-label-billing-private-endpoints-clusters/).
- Cross-region data egress when applications and the cluster are in different regions.
- `privatelink_regional_mode` adds no Atlas charge but creates more consumer endpoints and DNS records.

**Dev vs prod recommendation:**

- **Dev:** Public IP plus access list is acceptable.
- **Staging:** Single-region private endpoint ([Pattern 3](#3-pattern-single-region-same-region-clients)).
- **Production:** A private endpoint pattern that matches the production DR shape ([Pattern 5](#5-pattern-multi-region-cluster-peered-networks) or [Pattern 6](#6-pattern-multi-region-cluster-regional-connection-strings)).

Use one Atlas project per environment so toggles like `privatelink_regional_mode` cannot affect another environment.

## 10. GCP module configuration

| Pattern | Cluster module input | GCP module input | Worked example |
| --- | --- | --- | --- |
| [Single region, same-region clients](#3-pattern-single-region-same-region-clients) | One region in `regions` | [`privatelink_endpoints`](../README.md#privatelink_endpoints) (one entry) | [`examples/privatelink`](../examples/privatelink) |
| [Single region, cross-region clients](#4-pattern-single-region-cross-region-clients) | One region in `regions` | `all_region_mode = true` on the endpoint object | [`examples/privatelink_global_access`](../examples/privatelink_global_access) |
| Single region, multi-VPC | One region in `regions` | [`privatelink_endpoints_single_region`](../README.md#privatelink_endpoints_single_region) | See README variable reference |
| [Multi-region, peered networks](#5-pattern-multi-region-cluster-peered-networks) | Multi-region `regions`; regional mode default | [`privatelink_endpoints`](../README.md#privatelink_endpoints) (one entry per cluster region) | Adapt [`examples/privatelink_multi_region`](../examples/privatelink_multi_region) (drop `privatelink_regional_mode`) |
| [Multi-region, regional connection strings](#6-pattern-multi-region-cluster-regional-connection-strings) | Geo-sharded `regions` | `privatelink_endpoints` + `privatelink_regional_mode = "auto"` | [`examples/privatelink_multi_region`](../examples/privatelink_multi_region) |
| [BYO Endpoint](#7-delivery-option-byo-endpoint) (any pattern) | Any pattern above | [`privatelink_byo_endpoint`](../README.md#privatelink_byo_endpoint) and [`privatelink_byo_service`](../README.md#privatelink_byo_service) | [`examples/privatelink_byoe`](../examples/privatelink_byoe) |
| Reference: full module integration | Multi-feature | PSC + encryption + backup | [`examples/complete`](../examples/complete) |

**Regional-mode dependency ordering:** Clusters that depend on `privatelink_regional_mode` should declare `depends_on = [module.atlas_gcp]` (or an explicit dependency on `mongodbatlas_private_endpoint_regional_mode`) so Atlas updates the project-level setting before the cluster apply runs. See the [v0.2.0 upgrade guide](v0.2.0-upgrade-guide.md#private-endpoint-regional-mode-breaking-change).

**Region keys:** Module-managed `privatelink_endpoints` keys normalize to GCP format (`us-east4`). Deployments that previously used Atlas-format keys (`US_EAST_4`) need `moved` blocks; see the [v0.2.0 upgrade guide](v0.2.0-upgrade-guide.md#privatelink-region-key-normalization-breaking-change).

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

GCP PSC uses one forwarding rule per Atlas service region. Atlas multiplexes shard traffic on that rule by mapping cluster ports internally; this is the "port-mapped PSC" architecture. Legacy `pl-*` hostnames from older Atlas integrations are deprecated and removed in April 2027 — new deployments do not see them.

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
- [Google PSC + MongoDB codelab](https://codelabs.developers.google.com/codelabs/psc-mongo-globalaccess)
