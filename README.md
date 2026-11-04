# Apigee Terraform Core

This repository provides Terraform configuration to deploy Apigee X in a GCP project and region. It supports configurable control plane endpoints (either Data Residency Zones / DRZ like `eu`, `us`, `in`, or the default `global` endpoint) and configurable billing types (`PAYG`, `TRIAL`, or `SUBSCRIPTION`).

To prevent issues with Apigee's **minimum 24-hour retention period upon organization deletion**, the deployment is split into two independent **stages**:
1. **Stage 1 (`tf/01-org`)**: Permanent foundation. Enables required GCP service APIs and provisions the Apigee Organization with `prevent_destroy = true`. Run once.
2. **Stage 2 (`tf/02-runtime`)**: Ephemeral runtime and ingress infrastructure. Provisions the Apigee instance, environments, Certificate Manager managed certificates, PSC NEG, and optional regional Application Load Balancer (ILB, XLB, or None). Can be destroyed, recreated, and iterated on freely without touching the Apigee organization.

---

## Architecture Overview

```
tf/
├── 01-org/                # Stage 1: Apigee Org & APIs (Protected)
│   ├── main.tf            # Service APIs + Apigee Org (prevent_destroy)
│   ├── variables.tf       # project_id, region, drz_location, billing_type
│   └── outputs.tf         # org_id, project_id, region, drz_location, billing_type, apigee_custom_endpoint
│
├── 02-runtime/            # Stage 2: Runtime, Networking & Load Balancing
│   ├── main.tf            # Instance, Env, PSC NEG, Certs, Regional ALB (ILB/XLB/None)
│   ├── variables.tf       # project_id, region, drz_location, lb_type, network, subnet, domain
│   └── outputs.tf         # lb_type, lb_ip_address, dns_authorization_record, drz_location, apigee_custom_endpoint
│
└── 03-all-in-one/         # Unified: Single-stage deployment
    ├── main.tf            # Org + APIs + Runtime + Load Balancing
    ├── variables.tf       # All variables combined (including drz_location, billing_type)
    └── outputs.tf         # Combined outputs
```

- **Apigee X Organization (`01-org`)**: Organization with configurable billing (`PAYG`, `TRIAL`/`EVALUATION`, or `SUBSCRIPTION`) and configurable control plane (DRZ e.g. `eu`, `us`, `in`, or global).
- **Apigee Runtime & Environments (`02-runtime`)**: Regional Apigee instance attached to the `dev` environment and `dev` environment group.
- **Regional Application Load Balancer (`02-runtime`)**: Envoy-based Application Load Balancer configurable via `lb_type`:
  - `ilb` (default): Regional Internal Application Load Balancer (`INTERNAL_MANAGED`).
  - `xlb`: Regional External Application Load Balancer (`EXTERNAL_MANAGED`).
  - `none`: No load balancer or certificate resources (provisions only Apigee instance and environments).
- **Private Service Connect NEG (`02-runtime`)**: Regional network endpoint group pointing directly to the Apigee instance service attachment (when `lb_type` is `ilb` or `xlb`).
- **Certificate Manager (`02-runtime`)**: Regional Google-managed SSL certificate validated via DNS authorization (when `lb_type` is `ilb` or `xlb`).

---

## Prerequisites

1. **VPC Network & Subnet**: A VPC network and subnet in the target region for the load balancer forwarding rule and PSC NEG (required when `lb_type` is `ilb` or `xlb`, unless `create_network = true`).
2. **Proxy-Only Subnet**: A regional proxy-only subnet in the same VPC and region (required by GCP for Envoy-based `INTERNAL_MANAGED` and `EXTERNAL_MANAGED` regional load balancers):
   - Purpose: `REGIONAL_MANAGED_PROXY`
   - Role: `ACTIVE`
   - Recommended size: `/23` to `/26` depending on expected proxy capacity (e.g., `10.129.0.0/23`)

---

## Stage 1: Apigee Organization (`tf/01-org`)

Run this stage once per GCP project. The Apigee organization is guarded with `lifecycle { prevent_destroy = true }`.

### Variables (`tf/01-org`)

| Variable | Description | Type | Default | Required |
|---|---|---|---|---|
| `project_id` | GCP Project ID (also used as the Apigee Organization name) | `string` | - | **Yes** |
| `region` | GCP region for Apigee analytics and consumer data location | `string` | - | **Yes** |
| `drz_location` | Apigee DRZ location (e.g., `eu`, `us`, `in`) or `null`/empty for global | `string` | `null` | No |
| `billing_type` | Billing type: `PAYG` (default), `TRIAL` (or `EVALUATION`, only valid for global), or `SUBSCRIPTION` | `string` | `"PAYG"` | No |

> [!NOTE]
> `TRIAL` / `EVALUATION` billing type is only supported on the **global** endpoint. When a DRZ location (`drz_location`) is specified, you must use either `PAYG` or `SUBSCRIPTION`.

### Deploy Stage 1

#### Example: Global PAYG Org (Default)
```sh
terraform -chdir=tf/01-org init
terraform -chdir=tf/01-org apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION"
```

#### Example: EU DRZ with PAYG
```sh
terraform -chdir=tf/01-org init
terraform -chdir=tf/01-org apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "billing_type=PAYG"
```

#### Example: Global TRIAL Org
```sh
terraform -chdir=tf/01-org init
terraform -chdir=tf/01-org apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=TRIAL"
```

---

## Stage 2: Runtime & Load Balancing (`tf/02-runtime`)

Run this stage to provision or iterate on the Apigee gateway runtime, environments, certificates, and optional load balancing.

### Variables (`tf/02-runtime`)

| Variable | Description | Type | Default | Required |
|---|---|---|---|---|
| `project_id` | GCP Project ID | `string` | - | **Yes** |
| `region` | GCP region for Apigee runtime instance and regional load balancer | `string` | - | **Yes** |
| `drz_location` | Apigee DRZ location (e.g. `eu`, `us`, `in`) used for the org, or `null`/empty for global | `string` | `null` | No |
| `lb_type` | Load balancer type: `ilb` (Regional Internal ALB), `xlb` (Regional External ALB), or `none` | `string` | `"ilb"` | No |
| `create_network` | Create a dedicated VPC network, subnet, and proxy-only subnet in the region | `bool` | `false` | No |
| `network` | VPC network name or self-link (required if `lb_type != "none"` and `create_network = false`) | `string` | `null` | Conditional |
| `subnet` | VPC subnetwork name or self-link (required if `lb_type != "none"` and `create_network = false`) | `string` | `null` | Conditional |
| `subnet_cidr_range` | Primary subnet CIDR block when `create_network` is true | `string` | `"10.0.0.0/24"` | No |
| `proxy_subnet_cidr_range` | Proxy-only subnet CIDR block when `create_network` is true | `string` | `"10.129.0.0/23"` | No |
| `domain` | Domain name for Certificate Manager cert & envgroup hostname | `string` | `"api.example.com"` | No |
| `apigee_org_id` | Optional explicit Apigee Org ID (defaults to `organizations/<project_id>`) | `string` | `null` | No |

### Deploy Stage 2

#### Option A: Auto-provision VPC and Subnets with Regional ILB (Default)
```sh
terraform -chdir=tf/02-runtime init
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

#### Option B: Use Existing VPC and Subnet with Regional ILB
You can create a `tf/02-runtime/terraform.tfvars` file:

```hcl
project_id   = "my-apigee-project"
region       = "europe-west1"
drz_location = "eu"
lb_type      = "ilb"
network      = "my-vpc"
subnet       = "my-subnet-europe-west1"
domain       = "api.example.com"
```

Then initialize and apply:

```sh
terraform -chdir=tf/02-runtime init
terraform -chdir=tf/02-runtime apply
```

Or pass variables directly via CLI `-var` flags:

```sh
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "network=my-vpc" \
  -var "subnet=my-subnet-europe-west1" \
  -var "domain=api.example.com"
```

#### Option C: Regional External Load Balancer (`lb_type = "xlb"`)
Deploys a regional external Application Load Balancer (`EXTERNAL_MANAGED`) with a public IP and Google-managed certificate:

```sh
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

#### Option D: No Load Balancer (`lb_type = "none"`)
Provisions only the Apigee instance and environments without any VPC networking, load balancer, or Certificate Manager resources:

```sh
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "lb_type=none"
```

---

## All-in-One Template (`tf/03-all-in-one`)

For automated pipelines or environments where a single-stage deployment is preferred, `tf/03-all-in-one` combines Stage 1 and Stage 2 into a single unified Terraform root module containing:
- `main.tf`: Enables required APIs, creates the Apigee Org (protected by `prevent_destroy`), Apigee runtime instance, environments, Certificate Manager certs, PSC NEG, and regional load balancer.
- `variables.tf`: Unified variable definitions (`project_id`, `region`, `drz_location`, `billing_type`, `lb_type`, `create_network`, `network`, `subnet`, etc.).
- `outputs.tf`: Combined outputs (`org_id`, `billing_type`, `drz_location`, `apigee_custom_endpoint`, `lb_ip_address`, `dns_authorization_record`, `apigee_instance_id`, etc.).

### Deploy All-in-One

```sh
terraform -chdir=tf/03-all-in-one init
terraform -chdir=tf/03-all-in-one apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "billing_type=PAYG" \
  -var "create_network=true" \
  -var "lb_type=ilb" \
  -var "domain=api.example.com"
```

> [!NOTE]
> The Apigee Organization in `03-all-in-one` is protected with `lifecycle { prevent_destroy = true }`. If you need to destroy and recreate the runtime frequently without risking the 24-hour org deletion lockout, use the two-stage approach (`01-org` + `02-runtime`) instead.

---

## Post-Deployment: DNS Authorization

When `lb_type` is `ilb` or `xlb`, the deployment provisions a Google-managed certificate through Certificate Manager using a regional DNS authorization challenge. To complete certificate issuance:

1. Obtain the DNS authorization record from Stage 2 Terraform outputs:
   ```sh
   terraform -chdir=tf/02-runtime output dns_authorization_record
   ```
2. In your DNS provider (e.g. Cloud DNS), create the CNAME record matching the output:
   - **Name**: The record name provided in the output (e.g., `_acme-challenge.api.example.com.`)
   - **Type**: `CNAME`
   - **Data**: The target domain provided in the output

Once the DNS record resolves, Google Cloud will automatically provision and renew the managed certificate.

---

## Safe Cleaning & Teardown

To avoid deleting the Apigee Organization state, `sh/tfclean.sh` targets **Stage 2 (`02-runtime`)** by default:

```sh
# Safely clean runtime cache & state (Stage 1 org state remains untouched)
./sh/tfclean.sh

# Or destroy Stage 2 resources cleanly using Terraform
terraform -chdir=tf/02-runtime destroy
```

If you ever need to reset both stages (requires caution if the Org exists in GCP):
```sh
./sh/tfclean.sh all
```

---

## Outputs Reference

### Stage 1 Outputs (`tf/01-org`)

| Output | Description |
|---|---|
| `org_id` | Apigee organization resource ID (`organizations/<project_id>`) |
| `project_id` | GCP Project ID |
| `region` | Analytics and consumer data region |
| `drz_location` | Configured DRZ location (or `null` for global) |
| `billing_type` | Normalized Apigee billing type (`PAYG`, `EVALUATION`, or `SUBSCRIPTION`) |
| `apigee_custom_endpoint` | Custom endpoint URI used for Apigee API calls |

### Stage 2 Outputs (`tf/02-runtime`)

| Output | Description |
|---|---|
| `lb_type` | Configured load balancer mode (`none`, `ilb`, or `xlb`) |
| `lb_ip_address` | Reserved frontend IP address (internal for ILB, external for XLB, `null` if `none`) |
| `dns_authorization_record` | CNAME record details for the Certificate Manager domain challenge (`null` if `none`) |
| `apigee_instance_id` | ID of the provisioned Apigee runtime instance |
| `apigee_service_attachment` | Service attachment URI of the Apigee instance |
| `drz_location` | Configured DRZ location (or `null` for global) |
| `apigee_custom_endpoint` | Custom endpoint URI used for Apigee API calls |
| `network` | VPC network used for the load balancer (`null` if `none`) |
| `subnet` | VPC subnetwork used for the load balancer (`null` if `none`) |


