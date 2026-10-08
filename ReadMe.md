# Cribl Observability POV - Terraform Repository

Complete Infrastructure-as-Code for a Cribl Stream observability proof-of-concept deployment demonstrating data normalization, structural repair, and volume reduction across 3 pipelines flowing to New Relic, S3, and Cribl Lake.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOG SOURCES                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ Kubernetes   │  │ Prometheus   │  │   Syslog     │           │
│  │ (Fluent Bit) │  │  Metrics     │  │   (Network)  │           │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │
└─────────┼──────────────────┼──────────────────┼──────────────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                      │
          ┌───────────▼────────────┐
          │    Splunk HEC Input    │
          │    (Port 8088, TLS 1.3)│
          └───────────┬────────────┘
                      │
┌─────────────────────▼────────────────────────────────────────────┐
│                 CRIBL STREAM WORKER GROUP                        │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Pipeline 1: NORMALIZE & LABEL                             │ │
│  │  ├─ Eval: Rename fields (severity→level, msg→message)     │ │
│  │  ├─ Lookup: Namespace→Team mapping                        │ │
│  │  └─ Eval: Tag missing labels, add metadata                │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Pipeline 2: STRUCTURE REPAIR                              │ │
│  │  ├─ Regex: Extract severity from text logs                │ │
│  │  ├─ Serde: JSON parse multi-line traces                   │ │
│  │  └─ Eval: Normalize timestamp to ISO8601                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Pipeline 3: VOLUME REDUCTION                              │ │
│  │  ├─ Drop: Filter DEBUG in production                      │ │
│  │  ├─ Sample: Logarithmic sampling on appId+namespace       │ │
│  │  └─ Drop: Filter empty message bodies                     │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────┬──────────────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          │ Smart Output Router   │
          └────┬────┬────────┬────┘
              │    │        │
    ┌─────────┘    │        └─────────┐
    │              │                  │
    ▼              ▼                  ▼
┌─────────────┐ ┌──────────┐  ┌──────────────┐
│ New Relic   │ │ S3       │  │ Cribl Lake   │
│ (Errors)    │ │ (Info)   │  │ (Archive)    │
│             │ │ (Debug)  │  │              │
└─────────────┘ └──────────┘  └──────────────┘
```

## Directory Structure

```
cribl-o11y-pov-terraform/
├── cribl/                              # Cribl Stream configuration
│   ├── main.tf                         # Provider configuration
│   ├── worker_group.tf                 # Worker group definition
│   ├── sources.tf                      # Splunk HEC input source
│   ├── pipelines.tf                    # 3 data pipelines
│   ├── lookups.tf                      # Lookup file configurations
│   ├── destinations.tf                 # 4 output destinations
│   ├── routes.tf                       # Smart routing rules
│   ├── commit_deploy.tf                # Git commit & deployment
│   ├── variables.tf                    # Terraform variables
│   ├── outputs.tf                      # Output values
│   ├── terraform.tfvars.example        # Variable template
│   ├── terraform.tfvars                # Local variables (not committed)
│   └── data/
│       └── namespace_team_map.csv      # Namespace→Team lookup table
├── k8s/                                # Kubernetes configurations
│   ├── kind-config.yaml                # KIND cluster (4-node, v1.36+)
│   ├── namespaces.yaml                 # 4 namespaces (payments, checkout, etc.)
│   ├── log-generators.yaml             # 3 sample log-gen deployments
│   └── fluent-bit-helm-values.yaml     # Fluent Bit config for HEC output
├── eks/                                # EKS configurations (optional)
├── .gitignore                          # Terraform files to exclude
└── README.md                           # This file
```

## Prerequisites

- **Terraform** >= 1.0
- **Cribl Cloud** account with OAuth2 credentials
- **AWS Account** for S3 bucket and optional EKS
- **kubectl** and **kind** (for local Kubernetes testing)
- **Helm** (for Fluent Bit deployment)
- **New Relic** account with ingest license key
- **Cribl Lake** endpoint (if using Lake destination)

## Quick Start

### 1. Prepare Terraform Variables

Copy the example template and populate with your values:

```bash
cd cribl-o11y-pov-terraform/cribl
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your credentials
# - Cribl Cloud OAuth2 client ID and secret
# - Cribl organization ID
# - New Relic API key
# - S3 bucket name
# - Splunk HEC authentication token
# - Cribl Lake endpoint
```

### 2. Initialize Terraform

```bash
cd cribl-o11y-pov-terraform/cribl
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan -out=tfplan
```

### 4. Apply the Configuration

```bash
terraform apply tfplan
```

### 5. Verify Deployment

```bash
terraform output
```

Output will include:
- Worker group ID
- HEC source endpoint
- S3 bucket path
- New Relic dashboard link

## Day-by-Day Breakdown

### Day 1: Foundations
- ✅ Fixed provider version (`~> 1.25`)
- ✅ Renamed worker group to `cribl-o11y-pov`
- ✅ Created Splunk HEC source (port 8088, TLS 1.3)
- ✅ Added all required variables
- ✅ Created `terraform.tfvars.example` template

### Day 2: Pipelines
- ✅ **normalize-and-label**: 3 functions (Eval, Lookup, Eval)
- ✅ **structure-repair**: 3 functions (Regex, Serde, Eval)
- ✅ **volume-reduction**: 3 functions (Drop, Sample, Drop)
- ✅ Lookup file: `namespace_team_map.csv`

### Day 3: Destinations & Routing
- ✅ **new-relic**: Native New Relic destination
- ✅ **s3-parquet**: Parquet + Snappy compression, partitioned
- ✅ **cribl-lake**: Lake data archival
- ✅ **output-router**: Smart routing based on log levels
- ✅ 3 routes: Errors→NR, Info/Debug→S3+Lake, Default→NR
- ✅ Commit & Deploy resources

### Day 4: Kubernetes Configuration
- ✅ KIND cluster: 4-node (1 control-plane, 3 workers), v1.36+
- ✅ 4 namespaces: payments, checkout, unknown-team, logging
- ✅ 3 log-gen deployments: 2 replicas each with inline scripts
- ✅ Fluent Bit Helm values: HEC output, TLS 1.3, structured logging

### Day 5: Finalization
- ✅ Comprehensive outputs
- ✅ Complete README with architecture diagram
- ✅ Troubleshooting section
- ✅ All files syntax-checked

## Configuration Details

### Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `cribl_client_id` | string | Yes | Cribl Cloud OAuth2 client ID |
| `cribl_client_secret` | string | Yes | Cribl Cloud OAuth2 client secret |
| `cribl_organization_id` | string | Yes | Cribl Cloud organization ID |
| `cribl_workspace_id` | string | No | Cribl workspace (default: `main`) |
| `nr_license_key` | string | Yes | New Relic ingest license key |
| `hec_auth_token` | string | Yes | Splunk HEC authentication token |
| `s3_bucket_name` | string | Yes | S3 bucket for log archival |
| `aws_region` | string | No | AWS region (default: `us-west-2`) |
| `lake_endpoint` | string | Yes | Cribl Lake endpoint URL |

### Pipelines

#### 1. normalize-and-label
```
Eval(rename fields) → Lookup(namespace→team) → Eval(tag missing labels)
```
- Renames: `severity→level`, `msg→message`, `source→src`
- Maps namespaces to teams via lookup table
- Adds `__source_type` and `__missing_labels` metadata

#### 2. structure-repair
```
Regex(extract severity) → Serde(parse JSON) → Eval(normalize timestamps)
```
- Extracts severity from text logs using regex
- Parses multi-line JSON traces
- Normalizes timestamps to ISO8601, severity levels to standard

#### 3. volume-reduction
```
Drop(DEBUG in prod) → Sample(logarithmic) → Drop(empty messages)
```
- Filters DEBUG logs in production environments
- Applies 10% logarithmic sampling per appId+namespace
- Removes empty message bodies

### Destinations

| Destination | Type | Details |
|-------------|------|---------|
| **new-relic** | newrelic | Native New Relic OTLP endpoint |
| **s3-parquet** | output_s3 | Parquet format, Snappy compression, partitioned by date |
| **cribl-lake** | output_cribl_lake | Lake format, date-partitioned |
| **output-router** | output_router | Smart routing based on log levels and filters |

### Routes

1. **Errors to New Relic** (Priority 1)
   - Filter: `level === 'error' || level === 'fatal'`
   - Pipeline: normalize-and-label
   - Destination: new-relic

2. **Info/Debug to S3 & Lake** (Priority 2)
   - Filter: `level === 'info' || level === 'debug'`
   - Pipeline: volume-reduction
   - Destinations: s3-parquet, cribl-lake

3. **Default to New Relic** (Priority 3)
   - Filter: `true` (catch-all)
   - Pipeline: structure-repair
   - Destination: new-relic

## Kubernetes Setup

### Create KIND Cluster

```bash
kind create cluster --config k8s/kind-config.yaml --name cribl-o11y-pov
```

### Deploy Namespaces

```bash
kubectl apply -f k8s/namespaces.yaml
```

### Deploy Log Generators

```bash
kubectl apply -f k8s/log-generators.yaml
```

### Deploy Fluent Bit

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values k8s/fluent-bit-helm-values.yaml
```

### Verify Deployment

```bash
# Check namespaces
kubectl get namespaces

# Check log generators
kubectl get deployments -n payments
kubectl get deployments -n checkout
kubectl get deployments -n unknown-team

# Check Fluent Bit
kubectl get daemonset -n logging
kubectl get pods -n logging
```

## Troubleshooting

### Issue: Terraform State Mismatch

**Symptom**: `Error: Resource already exists`

**Solution**:
```bash
# Import existing resources
terraform import criblio_group.cribl_o11y_pov cribl-o11y-pov
```

### Issue: HEC Connection Refused

**Symptom**: `Connection refused to HEC endpoint`

**Causes**:
- HEC source not running
- TLS certificate not trusted
- Network connectivity issue

**Solution**:
```bash
# Test HEC connectivity
curl -k -H "Authorization: Splunk YOUR_HEC_TOKEN" \
  https://cribl-o11y-pov.cribl.cloud:8088/services/collector \
  -d '{"event":"test"}'

# Check worker group status
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  https://main-${ORG_ID}.cribl.cloud/api/v1/groups/cribl-o11y-pov
```

### Issue: S3 Permission Denied

**Symptom**: `Access Denied to S3 bucket`

**Solution**:
- Verify IAM role has `s3:PutObject` and `s3:PutObjectAcl` permissions
- Check bucket policies allow the role
- Verify bucket name matches configuration

### Issue: New Relic Data Not Appearing

**Symptom**: No logs in New Relic dashboard

**Causes**:
- API key invalid or expired
- Route filter not matching logs
- Destination endpoint unreachable

**Solution**:
```bash
# Verify route configuration
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  https://main-${ORG_ID}.cribl.cloud/api/v1/groups/cribl-o11y-pov/routes

# Check pipeline execution
# Enable debug logging: Run `terraform apply -var='log_level=debug'`
```

### Issue: Kubernetes Log Collection Not Working

**Symptom**: No logs reaching Splunk HEC from Fluent Bit

**Solution**:
```bash
# Check Fluent Bit logs
kubectl logs -n logging -l app=fluent-bit --tail=100

# Verify log generators
kubectl logs -n payments deployments/payments-log-generator

# Test HEC connectivity from pod
kubectl run -it --image=curlimages/curl:latest \
  --rm debug -- sh -c 'curl -k https://CRIBL_WORKER:8088'
```

## Monitoring & Observability

### New Relic Queries

View logs by namespace:
```kuery
namespace = 'payments' OR namespace = 'checkout'
```

Track error rates:
```kuery
level = 'error' OR level = 'fatal' | stats count by namespace, level
```

### S3 Data

View archived logs:
```bash
aws s3 ls s3://YOUR_BUCKET/o11y-pov/ --recursive --human-readable
```

### Cribl Lake

Query Lake data via Lake UI or API.

## Cost Optimization Tips

1. **Sampling**: Adjust logarithmic sampling ratio in volume-reduction pipeline
2. **TTL**: Configure S3 lifecycle policies for older data
3. **Lake Partitioning**: Use date-based partitions for efficient queries
4. **Worker Group**: Adjust `estimated_ingest_rate` based on actual volume

## References

- **Cribl Documentation**: https://docs.cribl.io
- **Cribl API Reference**: https://docs.cribl.io/stream/api-reference
- **Terraform Provider**: https://registry.terraform.io/providers/criblio/criblio/latest/docs
- **Lesson Plan**: ~/cribl-o11y-pov/lesson-plan/

## Support & Next Steps

1. **Validate Deployment**: Run `terraform plan` to verify state
2. **Test End-to-End**: Send test logs via HEC, verify in New Relic/S3/Lake
3. **Monitor**: Set up New Relic dashboards and alerts
4. **Scale**: Adjust worker group capacity and sampling as needed
5. **Production**: Extend to EKS cluster with persistent state management

---

**Author**: Cribl SE Team  
**Version**: 1.0  
**Last Updated**: October 2026  
**Status**: Production Ready
