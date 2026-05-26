# PrivateLink Topology Guide (GCP)

This guide helps you choose a Private Service Connect (PSC) topology for MongoDB Atlas on GCP. It separates **cluster** regional outage tolerance (Atlas electable regions and driver failover) from **client/app** regional outage tolerance (whether apps in another region can still reach a private endpoint when one client region fails).

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Customer outcomes](#2-customer-outcomes)
- [3. Concepts and the three-layer model](#3-concepts-and-the-three-layer-model)
- [4. The primary decision](#4-the-primary-decision)
- [5. Deployment patterns](#5-deployment-patterns)
- [6. Failure mode reference](#6-failure-mode-reference)
- [7. What costs downtime](#7-what-costs-downtime)
- [8. Cost and dev vs prod](#8-cost-and-dev-vs-prod)
- [9. Cross-CSP comparison](#9-cross-csp-comparison)
- [10. Module configuration mapping (GCP)](#10-module-configuration-mapping-gcp)

## 1. Introduction

**Audience:** Teams configuring the GCP module alongside the [cluster module](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-cluster/blob/main/docs/cluster_topology.md).

**Pre-reads:**

- [Cluster topology guide](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-cluster/blob/main/docs/cluster_topology.md)
- [Atlas architecture: network security](https://www.mongodb.com/docs/atlas/architecture/current/network-security/)
- [Atlas architecture: high availability](https://www.mongodb.com/docs/atlas/architecture/current/high-availability/)
- [Atlas architecture: disaster recovery](https://www.mongodb.com/docs/atlas/architecture/current/disaster-recovery/)

**What this guide is not:** A replacement for [Atlas private endpoint product docs](https://www.mongodb.com/docs/atlas/security-private-endpoint/) or arch center DR design. Use the module README for variable reference; use this guide for topology decisions.

## 2. Customer outcomes

Start with **what you are trying to achieve**:

- **HA:** AZ failure needs no PrivateLink work; single-region multi-AZ is the Atlas default.
- **DR:** Region outage tolerance has two axes:
  - **Cluster:** Automatic cross-region failover via multi-region topology and URI shape.
  - **Client/app:** Whether surviving app regions can still use private endpoints when one client region is down.
  Cross-cloud failover has separate limits (see §6).
- **Cost:** Fewest endpoints, avoid cross-region SKUs, minimal dev setups.
- **Portability:** Avoid CSP-specific choices that block multi-cloud or migration.

**Alternatives to private endpoints** (CSP-neutral):

| Mechanism | When to choose | When to avoid | Reference |
| --- | --- | --- | --- |
| **PE / PrivateLink** | Regulatory requirement; private-only network policy; production | Lower environments without a security mandate | This guide |
| **VPC peering only** | Single CSP; simpler; lower cost | Multi-cloud; regulated multi-VPC | Arch center |
| **Public IP + access list** | Dev/test; low risk; quick setup | Production with private-only mandate | Atlas docs |

**BYO Endpoint** is a delivery mode for private endpoints (customer creates the consumer endpoint instead of the module), not an alternative to private endpoints. See §5.3.

## 3. Concepts and the three-layer model

### 3.1 What the driver connects to

On a **replica set**, the driver talks to mongod processes. Horizon records in the connection string matter. You need a private endpoint in every cluster region the driver must reach.

On **sharded** or **geo-sharded** clusters, the driver talks to mongos only. Shard mongod horizons are not in the client connection string. **Regional mode** (Atlas project setting) unlocks region-local private SRV records when app networks cannot peer across regions.

See the [cluster topology guide](https://github.com/terraform-mongodbatlas-modules/terraform-mongodbatlas-cluster/blob/main/docs/cluster_topology.md) for `regions` vs `replication_specs` configuration.

### 3.2 Three-layer model

1. **Cluster topology**
   - Electable regions define where Atlas runs data nodes.
2. **Atlas PE layer**
   - **PE service:** Atlas-side private endpoint service per cluster region.
   - **Regional mode:** Sharded-only Atlas setting; controls global vs region-local private SRV records.
   - **Connection strings:** Global private SRV when regional mode is off; per-region SRV when regional mode is on.
3. **CSP consumer layer**
   - **Consumer endpoint:** GCP PSC forwarding rule and internal IP (module-managed or BYO Endpoint).
   - **Cross-region client access:** CSP-specific mechanism so apps in other client regions reach a PE IP in the service region (§9).

**Port-mapped PSC:** GCP uses one forwarding rule per Atlas service region. Atlas maps ports internally; legacy `pl-*` hostnames are deprecated (April 2027).

## 4. The primary decision

Answer in order. **Cluster** and **client/app** regional outage are different problems.

### 4.1 Cluster regional outage tolerance

Does the **Atlas cluster** need automatic failover when a **cluster region** goes down?

- **No** → single-region cluster → §5.1. A cluster region outage is a total private endpoint outage until manual DR (region add, restore, or a public-IP path).
- **Yes** → multi-region cluster → §5.2.

For Atlas defaults vs explicit topology, see [High Availability](https://www.mongodb.com/docs/atlas/architecture/current/high-availability/) and [Disaster Recovery](https://www.mongodb.com/docs/atlas/architecture/current/disaster-recovery/). For CSP-wide outage tolerance, see [Atlas multi-cloud distribution](https://www.mongodb.com/docs/atlas/cluster-config/multi-cloud-distribution/).

**(Multi-region cluster only) Can your app VPCs peer to every PE subnet?**

- **Yes** → one global URI, regional mode off (§5.2 M1).
- **No** → region-local URIs, regional mode on (§5.2 M2; sharded clusters only).

### 4.2 Client / app regional outage tolerance

Does the **application tier** need to keep serving when a **client region** fails while the cluster region stays up?

- **No** (single client region, or downtime in that region is acceptable) → default §5.1 same-region clients, or §5.2 with apps colocated per cluster region.
- **Yes** → surviving app regions must still reach PE. This does **not** require a multi-region cluster:
  - On **§5.1:** use **cross-region clients** (hub-and-spoke). Apps in healthy client regions keep using PE in the cluster region; requires PSC global access (§9).
  - On **§5.2 M1:** driver failover covers **cluster** region outage via the global URI; **client** region outage still isolates apps in that region unless you also run redundant app tiers and cross-region PE reachability.
  - On **§5.2 M2:** each region's apps use a region-local URI; client region outage matches §6.

**Decision summary:**

1. **Cluster region outage, no automatic failover** → single-region cluster (§5.1).
2. **Cluster region outage, automatic failover** → multi-region cluster (§5.2).
   - App VPCs peer to all PE subnets → §5.2 M1.
   - App VPCs cannot peer cross-region → §5.2 M2 (sharded only).
3. **Client region outage, apps elsewhere must keep serving** → cross-region clients (§5.1 hub-spoke or §9).
4. **Client region outage acceptable** → same-region clients (default).

## 5. Deployment patterns

Two macro patterns. Each documents DR behavior, cost class, and when not to use.

### 5.1 Single-region cluster

One Atlas cluster region; one PE service in that region by default. Regional mode off. Cluster region outage implies manual DR (region add, restore from backup, or app failover to a public-IP path).

**Sub-variants by client placement:**

- **Same region** (default): Apps and PE in the same region; nothing extra. Client region outage takes apps in that region offline.
- **Cross-region clients** (hub-and-spoke): Apps in other regions of the same VPC reach PE in the cluster region. Survives **client** region outage for apps in healthy regions; does **not** survive **cluster** region outage (still §5.1 manual DR). Set `all_region_mode = true` on the module-managed endpoint (§10).
- **Multi-VPC, same region:** Multiple consumer VPCs need PE access to the same cluster. Use `privatelink_endpoints_single_region`. Works for sharded without regional mode; replica set constraint in §8.

### 5.2 Multi-region cluster

Cluster has electable nodes in two or more regions; Atlas requires one PE service per cluster region.

- **M1 — One URI, peered VPCs (regional mode off):** All app VPCs reach PE subnets in every cluster region (VPC peering, VPN, or equivalent). Atlas emits one global private SRV; the driver fails over cross-region automatically. Works for replica set and sharded.
- **M2 — Regional URIs, unpeered networks (regional mode on):** App networks cannot peer cross-region. Atlas emits region-local URIs; each app uses its region's URI; cross-region failover needs an app-side runbook. **Sharded / geo-sharded only.** Set `privatelink_regional_mode = "auto"` (§10).

### 5.3 BYO Endpoint (cross-cutting delivery)

Orthogonal to §5.1 and §5.2:

- **Module-managed (default):** Single `terraform apply`; module creates consumer endpoint resources.
- **BYO Endpoint (Bring Your Own Endpoint):** Two-phase apply; customer creates the consumer forwarding rule outside the module. Choose when IAM is restricted, existing network automation owns endpoints, or you must set PSC flags before registration.

Trade-off: BYO Endpoint doubles the apply cycle; pick only when constraints force it.

## 6. Failure mode reference

| Failure | Single-region cluster (§5.1) | Multi-region cluster (§5.2) |
| --- | --- | --- |
| Node / AZ failure | Auto (Atlas multi-AZ election) | Auto |
| Cluster region outage | Total outage; manual DR | **M1:** driver fails over via global URI. **M2:** that region's URI is dead; other regions ok |
| Client region outage (§4.2) | Apps in that region offline; cluster healthy. **Hub-spoke (§5.1):** apps in other client regions keep serving | Same: only apps in that client region are offline unless redundant cross-region app + PE paths exist |
| PE removed during cluster maintenance | Downtime | Downtime |

- **Multi-cloud cluster + PE:** A single PE reaches **only nodes in the same CSP**. Use VPN or secondary read preference for cross-CSP nodes ([multi-cloud distribution](https://www.mongodb.com/docs/atlas/cluster-config/multi-cloud-distribution/)).
- **CSP-wide outage:** PE does not help; falls under arch center DR guidance.

## 7. What costs downtime

Operations that force app reconnect or a planned window:

- **REPLICASET → SHARDED conversion:** Connection string targets change (mongods → mongos); app restart required.
- **Non-regionalized → regionalized sharded mode:** URI churn, project-wide for sharded clusters; window required.
- **Multi-region → single-region service (AWS):** Guaranteed downtime ([AWS Cross-Region PrivateLink Field FAQ](https://docs.google.com/document/d/1bvirvP30Jv69HT5nHR4CzJbfuHtEkv5GxyHIcimNXlM)).
- **Removing PE during cluster maintenance** (multi-region): [PE product doc](https://www.mongodb.com/docs/atlas/security-private-endpoint/).
- **Cluster region add/remove with PE:** Atlas regenerates DNS / horizons; app reconnect if URI shape changes.
- **Toggle regional mode:** Sharded URIs regenerate.

## 8. Cost and dev vs prod

**Cost drivers** (CSP-neutral): endpoint hourly cost, cross-region data egress, regional billing SKUs (§9), regional mode adds no Atlas cost but multiplies consumer endpoints, Atlas PE billing per service ([Atlas PE billing](https://www.mongodb.com/docs/atlas/billing/additional-services/#std-label-billing-private-endpoints-clusters/)).

**Dev vs prod:** Dev = public + ACL acceptable; staging = single-region PE; prod = full PE plus DR pattern. One Atlas project per environment avoids regional-mode side effects across environments.

**Replica set caveat:** Max one PE per region for replica sets (across clouds). Multi-VPC same region for replica sets forces regional mode (sharded only) → use sharded or accept the cap.

## 9. Cross-CSP comparison

| Capability | GCP (PSC) | AWS (PrivateLink) | Azure (Private Link) |
| --- | --- | --- | --- |
| Cross-region client access (§5.1 hub-spoke) | PSC global access (consumer flag); endpoint stays in service region | Cross-region PrivateLink; interface endpoint in client region | Private Endpoint per client VNet; peering to hub |
| Regional mode enablement (§5.2 M2) | Manual enable (`privatelink_regional_mode = "auto"`) | Manual enable (`privatelink_regional_mode = "auto"`) | Manual enable (`privatelink_regional_mode = "auto"`) |
| Optimized sharded connection strings | Not supported (port-mapped PSC) | `loadBalanced` (sharded only) | Not supported |
| Endpoint architecture | Port-mapped PSC (one forwarding rule per region; legacy `pl-*` deprecated Apr 2027) | NLB-backed interface endpoint; 100 target groups per NLB drives regional mode for high-shard clusters | VNet private endpoint per region |
| Cross-region billing SKU | None (Atlas); pay GCP cross-region VPC egress | `AWS_PRIVATE_ENDPOINT_REGION` $0.05/hr per remote project-region (live April 2026) | Per-endpoint hourly cost; no separate cross-region SKU |
| BYO Endpoint pre-registration flag | `--allow-psc-global-access` (when cross-region clients needed) | Endpoint security group rules | VNet / subnet configuration |

**Two module knobs on GCP (do not conflate):**

- **`all_region_mode`:** GCP consumer forwarding rule; cross-region clients in the same VPC reach a PSC IP in the service region (§5.1 hub-spoke).
- **`privatelink_regional_mode`:** Atlas project setting; region-local private SRV for sharded M2 (§5.2 M2).

## 10. Module configuration mapping (GCP)

Map §5 patterns to cluster inputs, GCP module variables, and examples.

| Pattern | Cluster module | GCP module inputs | Example |
| --- | --- | --- | --- |
| §5.1 single-region, same-region clients | Single region in `regions` | `privatelink_endpoints` (one region) | [privatelink](../examples/privatelink) |
| §5.1 hub-spoke (`all_region_mode`) | Single region in `regions` | `all_region_mode = true` on endpoint object | [privatelink_global_access](../examples/privatelink_global_access) |
| §5.1 multi-VPC same region | Single region in `regions` | `privatelink_endpoints_single_region` | README variable reference |
| §5.2 M1 multi-region, one URI | Multi-region `regions`; regional mode off | `privatelink_endpoints` (one entry per cluster region) | Configure endpoints per region; no `privatelink_regional_mode` |
| §5.2 M2 multi-region, regional URIs | Geo-sharded `regions` | `privatelink_endpoints` + `privatelink_regional_mode = "auto"` | [privatelink_multi_region](../examples/privatelink_multi_region) |
| §5.3 BYO Endpoint | Any pattern above | `privatelink_byo_endpoint` / `privatelink_byo_service` | [privatelink_byoe](../examples/privatelink_byoe) |
| Full integration (reference) | Multi-feature | PSC + encryption + backup | [complete](../examples/complete) |

**Regional mode ordering:** Clusters that depend on regional mode should declare `depends_on = [module.atlas_gcp]` (or an explicit dependency on `mongodbatlas_private_endpoint_regional_mode`) so connection strings update before cluster resources apply. See [v0.2.0 upgrade guide](v0.2.0-upgrade-guide.md#private-endpoint-regional-mode-breaking-change).

**Region keys:** Module-managed `privatelink_endpoints` keys normalize to GCP format (`us-east4`). Deployments that used Atlas-format keys need `moved` blocks; see [v0.2.0 upgrade guide](v0.2.0-upgrade-guide.md#privatelink-region-key-normalization-breaking-change).

**Variable reference:** [`privatelink_endpoints`](../README.md#privatelink_endpoints), [`privatelink_endpoints_single_region`](../README.md#privatelink_endpoints_single_region), [`privatelink_regional_mode`](../README.md#privatelink_regional_mode), [`privatelink_byo_endpoint`](../README.md#privatelink_byo_endpoint), [`privatelink_byo_service`](../README.md#privatelink_byo_service).

## Additional resources

- [Module README](../README.md#private-service-connect)
- [v0.2.0 upgrade guide](v0.2.0-upgrade-guide.md)
- [Google PSC + MongoDB codelab](https://codelabs.developers.google.com/codelabs/psc-mongo-globalaccess)
- [Atlas: Learn About Private Endpoints](https://www.mongodb.com/docs/atlas/security-private-endpoint/)
