# Apigee Terraform Core

Deploy **Apigee X** on Google Cloud using simple command-line Terraform workflows. Supports `TRIAL`, `PAYG`, and `SUBSCRIPTION` billing, `global` or Data Residency Zone (`DRZ`) control planes, and optional regional External (`xlb`) or Internal (`ilb`) HTTPS Load Balancers with auto-created VPC networking.

## Choose Your Layout

```text
tf/
├── 03-all-in-one/   # Easiest: APIs + Org + Network + Runtime + Load Balancer in one step
├── 01-org/          # Stage 1: APIs + Apigee Org (protected with prevent_destroy)
└── 02-runtime/      # Stage 2: Runtime + Network + Load Balancer (destroy/recreate anytime)
```

- **All-in-One (`tf/03-all-in-one`)**: Fastest way to spin up everything in a single command.
- **Two-Stage (`tf/01-org` + `tf/02-runtime`)**: Keeps the Apigee Org isolated in `01-org` (GCP enforces a 24-hour retention lockout if an Apigee Org is deleted) so you can freely iterate on or destroy the runtime and load balancer in `02-runtime`.

Set your target project and region before running the examples below:

```sh
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_LOCATION="us-central1"
```

---

## 1. Quick Start: Global `TRIAL` + External LB (`xlb`)

The easiest path from an empty GCP project to a live, publicly reachable Apigee X gateway. Uses free evaluation billing (`TRIAL`) on the global control plane, auto-creates the VPC and proxy-only subnet (`create_network=true`), and provisions a Regional External HTTPS Load Balancer (`lb_type=xlb`).

### All-in-One (Recommended Quick Start)

```sh
terraform -chdir=tf/03-all-in-one init
terraform -chdir=tf/03-all-in-one apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=TRIAL" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

### Two-Stage (`01-org` + `02-runtime`)

```sh
# 1. Create Apigee Org (run once)
terraform -chdir=tf/01-org init
terraform -chdir=tf/01-org apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=TRIAL"

# 2. Create Runtime, VPC & External LB
terraform -chdir=tf/02-runtime init
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=TRIAL" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

---

## 2. `PAYG` Billing (Global + External LB)

Uses Pay-As-You-Go billing (`PAYG`) and configures the `dev` Apigee environment as `COMPREHENSIVE` (environment `type` is automatically set only when `billing_type=PAYG`).

### All-in-One

```sh
terraform -chdir=tf/03-all-in-one init
terraform -chdir=tf/03-all-in-one apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=PAYG" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

### Two-Stage (`01-org` + `02-runtime`)

```sh
terraform -chdir=tf/01-org init
terraform -chdir=tf/01-org apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=PAYG"

terraform -chdir=tf/02-runtime init
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=PAYG" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

---

## 3. Data Residency Zone (`DRZ`) + `PAYG`

Deploys Apigee using a regional Data Residency control plane (`eu`, `us`, or `in`).

> **Note:** `TRIAL` billing is only supported on the `global` endpoint. DRZ deployments require `PAYG` or `SUBSCRIPTION`.

### All-in-One (`eu` DRZ)

```sh
export GOOGLE_CLOUD_LOCATION="europe-west1"

terraform -chdir=tf/03-all-in-one init
terraform -chdir=tf/03-all-in-one apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "billing_type=PAYG" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

### Two-Stage (`eu` DRZ)

```sh
export GOOGLE_CLOUD_LOCATION="europe-west1"

terraform -chdir=tf/01-org init
terraform -chdir=tf/01-org apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "billing_type=PAYG"

terraform -chdir=tf/02-runtime init
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "drz_location=eu" \
  -var "billing_type=PAYG" \
  -var "lb_type=xlb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

---

## 4. Internal Load Balancer (`ilb`) & Networking Options

### Auto-Created VPC with Regional ILB (`lb_type=ilb`)

Creates a new VPC, subnet, and regional proxy-only subnet with a private Regional Internal HTTPS Load Balancer:

```sh
terraform -chdir=tf/03-all-in-one init
terraform -chdir=tf/03-all-in-one apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=PAYG" \
  -var "lb_type=ilb" \
  -var "create_network=true" \
  -var "domain=api.example.com"
```

### Existing VPC & Subnet with Regional ILB

If `create_network=false` (the default), pass your existing `network` and `subnet`. Your VPC must also have an `ACTIVE` proxy-only subnet (`purpose = REGIONAL_MANAGED_PROXY`) in the target region:

```sh
terraform -chdir=tf/02-runtime init
terraform -chdir=tf/02-runtime apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=PAYG" \
  -var "lb_type=ilb" \
  -var "network=my-vpc" \
  -var "subnet=my-subnet" \
  -var "domain=api.example.com"
```

### Runtime Only — No Load Balancer (`lb_type=none`)

Provisions only the Apigee runtime instance and `dev` environment without VPC, load balancer, or Certificate Manager resources:

```sh
terraform -chdir=tf/03-all-in-one init
terraform -chdir=tf/03-all-in-one apply \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION" \
  -var "billing_type=TRIAL" \
  -var "lb_type=none"
```

---

## Post-Deployment: HTTPS & DNS Setup

When `lb_type` is `xlb` or `ilb`, retrieve your load balancer IP and Certificate Manager DNS challenge record:

```sh
# Use tf/03-all-in-one or tf/02-runtime depending on how you deployed
terraform -chdir=tf/03-all-in-one output lb_ip_address
terraform -chdir=tf/03-all-in-one output dns_authorization_record
```

1. Create an **A record** pointing your `domain` to `lb_ip_address`.
2. Create the **CNAME record** shown in `dns_authorization_record` so Certificate Manager can issue and auto-renew the managed TLS certificate.

---

## Teardown & Local State Cleanup

In Two-Stage deployments, you can destroy the runtime and load balancer while keeping the Apigee Org intact:

```sh
terraform -chdir=tf/02-runtime destroy \
  -var "project_id=$GOOGLE_CLOUD_PROJECT" \
  -var "region=$GOOGLE_CLOUD_LOCATION"
```

To clean local `.terraform` caches and state files (defaults to `02-runtime` only to protect `01-org`):

```sh
./sh/tfclean.sh              # Cleans tf/02-runtime only
./sh/tfclean.sh all-in-one   # Cleans tf/03-all-in-one
./sh/tfclean.sh all          # Cleans all stages (use with caution)
```

---

## Variables Reference

| Variable | Default | Used In | Description |
|---|---|---|---|
| `project_id` | *(required)* | All | GCP Project ID (also used as Apigee Organization name) |
| `region` | *(required)* | All | GCP region for analytics, runtime instance, and load balancer |
| `billing_type` | `"PAYG"` | All | `PAYG`, `TRIAL` (`EVALUATION`, global only), or `SUBSCRIPTION` |
| `drz_location` | `null` | All | Data Residency Zone (`eu`, `us`, `in`) or `null` for global |
| `lb_type` | `"ilb"` | `02`, `03` | `xlb` (External ALB), `ilb` (Internal ALB), or `none` |
| `create_network` | `false` | `02`, `03` | Auto-create VPC, subnet, and regional proxy-only subnet |
| `network` | `null` | `02`, `03` | Existing VPC network (when `create_network=false` and `lb_type!=none`) |
| `subnet` | `null` | `02`, `03` | Existing subnet (when `create_network=false` and `lb_type!=none`) |
| `subnet_cidr_range` | `"10.0.0.0/24"` | `02`, `03` | Primary subnet CIDR when `create_network=true` |
| `proxy_subnet_cidr_range` | `"10.129.0.0/23"` | `02`, `03` | Proxy-only subnet CIDR when `create_network=true` |
| `domain` | `"api.example.com"` | `02`, `03` | Hostname for Apigee `dev` envgroup and managed TLS certificate |
| `apigee_org_id` | `null` | `02` | Explicit Apigee Org ID (defaults to `organizations/<project_id>`) |
