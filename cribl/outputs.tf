# ========================================
# DAY 5: OUTPUTS
# ========================================

output "worker_group_id" {
  description = "Worker group ID in Cribl Cloud"
  value       = criblio_group.cribl_o11y_pov.id
}

output "worker_group_name" {
  description = "Worker group name"
  value       = criblio_group.cribl_o11y_pov.name
}

output "hec_source_endpoint" {
  description = "HEC source endpoint URL for log ingestion"
  value       = "https://cribl-o11y-pov.cribl.cloud:8088"
}

output "s3_bucket_path" {
  description = "S3 bucket path for archived logs"
  value       = "s3://${var.s3_bucket_name}/o11y-pov/"
}

output "s3_bucket_partition_path" {
  description = "S3 partition path structure"
  value       = "o11y-pov/YYYY/MM/DD"
}

output "cribl_lake_endpoint" {
  description = "Cribl Lake endpoint URL"
  value       = var.lake_endpoint
}

output "newrelic_dashboard_link" {
  description = "New Relic dashboard link for monitoring"
  value       = "https://one.newrelic.com/nr1-core/explorer"
}

output "deployment_summary" {
  description = "Complete deployment summary"
  value = {
    org_url                  = "https://main-${var.cribl_organization_id}.cribl.cloud"
    group_id                 = criblio_group.cribl_o11y_pov.id
    workspace                = var.cribl_workspace_id
    pipelines_count          = 3
    destinations_count       = 4
    routes_count             = 3
    hec_port                 = 8088
    tls_version              = "1.3"
    s3_region                = var.aws_region
    kubernetes_namespaces    = 4
    kubernetes_deployments   = 3
  }
}

output "configuration_info" {
  description = "Configuration details for reference"
  value = {
    provider_version  = "~> 1.25"
    pipelines = {
      normalize = "normalize-and-label"
      repair    = "structure-repair"
      reduce    = "volume-reduction"
    }
    destinations = {
      newrelic = "new-relic-logs"
      s3       = "s3-parquet-logs"
      lake     = "cribl-lake-logs"
      router   = "output-router"
    }
    routes = {
      route_1 = "errors-to-newrelic"
      route_2 = "info-debug-to-s3-lake"
      route_3 = "default-to-newrelic"
    }
  }
}

output "troubleshooting_resources" {
  description = "Links to troubleshooting and documentation"
  value = {
    cribl_docs           = "https://docs.cribl.io"
    cribl_api_reference  = "https://docs.cribl.io/stream/api-reference"
    lesson_plan          = "~/cribl-o11y-pov/lesson-plan/"
    terraform_docs       = "https://registry.terraform.io/providers/criblio/criblio/latest/docs"
  }
}
