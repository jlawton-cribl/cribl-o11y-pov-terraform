# Cribl O11y POV - Terraform Deployment

## Configuration Status

This Terraform configuration sets up a complete observability pipeline in Cribl Cloud for the Nordstrom POV.

### Components

1. **Pipelines** (3 total):
   - `normalize-labels` - Normalize field names, add labels, flatten structure
   - `structure-repair` - Repair multiline traces, normalize severity, parse JSON
   - `volume-reduction` - Reduce volume by filtering noise and applying sampling

2. **Destinations** (3 total):
   - `newrelic-otlp` - New Relic OTLP HTTP endpoint for high-priority events
   - `s3-parquet` - S3 Parquet archive for long-term storage
   - `cribl-lake` - Cribl Lake for native query engine and searchability

3. **Routes** (3 total):
   - `route-errors-to-nr` - ERROR/FATAL logs → New Relic
   - `route-info-to-s3` - INFO/DEBUG logs → S3  
   - `route-all-to-lake` - All events → Cribl Lake

### Prerequisites

- Cribl Cloud organization: `lucid-solomon-w2cg0xb`
- Worker group: `demo-group-4` (already created)
- OAuth credentials (in terraform.tfvars)
- New Relic API key (in terraform.tfvars)
- S3 bucket configuration (in terraform.tfvars)

### Deployment Steps

#### Option 1: Manual API Deployment

Run the provisioning script directly:

```bash
cd cribl/
export CRIBL_CLIENT_ID="YOUR_CLIENT_ID"
export CRIBL_CLIENT_SECRET="YOUR_CLIENT_SECRET"
export CRIBL_ORG="lucid-solomon-w2cg0xb"
export CRIBL_GROUP="demo-group-4"
export NR_API_KEY="YOUR_NR_API_KEY"
export S3_BUCKET="cribl-o11y-pov-logs"
export S3_REGION="us-west-2"

bash provision.sh
```

#### Option 2: Via Terraform

```bash
cd cribl/
terraform init
terraform plan
terraform apply -auto-approve
```

Note: The Terraform workflow uses provisioners to call the Cribl API.

### Post-Deployment Verification

1. **In Cribl Cloud UI**:
   - Navigate to `demo-group-4` worker group
   - Check Pipelines tab → verify 3 pipelines created
   - Check Destinations tab → verify 3 destinations configured
   - Check Routes tab → verify 3 routes configured

2. **In New Relic**:
   - Log ingest should show data from the pipeline
   - Check for logs with source=normalize-labels, structure-repair, volume-reduction

3. **In S3**:
   - Bucket `cribl-o11y-pov-logs/cribl-o11y-pov/logs/` should have partitioned structure
   - Parquet files under `year=YYYY/month=MM/day=DD/hour=HH/`

4. **In Cribl Lake**:
   - Database `pov_logs`, table `observability_events` should exist
   - Data should be queryable via Cribl Search

### Configuration Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Input variables
- `terraform.tfvars` - Variable values (contains credentials)
- `provision.sh` - Provisioning script that deploys via API
- `pipelines/` - Pipeline JSON definitions
- `destinations/` - Destination configuration templates
- `routes.yaml` - Output router configuration

### Troubleshooting

**Issue: OAuth authentication fails**
- Verify client_id and client_secret are correct
- Check that the OAuth audience is properly configured
- Ensure the credentials have API permissions in Cribl Cloud

**Issue: Pipelines not appearing**
- Verify the `demo-group-4` group ID is correct
- Check Terraform logs for API errors
- Ensure all pipeline JSON files exist in `pipelines/` directory

**Issue: Destinations not connecting**
- Verify NR API key is valid
- Check S3 bucket and credentials
- Verify Lake endpoint is reachable
- Check Terraform provisioner output for errors

### Outputs

After successful deployment, Terraform outputs:
- Worker group ID
- Group name
- Summary of provisioned resources
- Deployment information (org URL, group, method)

### Next Steps

After resources are deployed:

1. **Create a test source** (Splunk HEC or Fluent Bit forwarder)
2. **Send sample data** to validate the pipeline
3. **Monitor** data flow in New Relic, S3, and Lake
4. **Tune pipelines** based on data patterns
5. **Scale configuration** to production workloads
