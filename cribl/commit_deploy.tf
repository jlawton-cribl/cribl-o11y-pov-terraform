# ========================================
# DAY 3: COMMIT & DEPLOY
# ========================================

resource "criblio_commit" "pov_commit" {
  group_id = criblio_group.cribl_o11y_pov.id
  message  = "O11y POV Day 1-3 setup: Worker group, sources, pipelines, lookups, destinations, and routes"
  reason   = "Terraform-applied observability pipeline for data normalization and routing"

  depends_on = [
    criblio_group.cribl_o11y_pov,
    criblio_source.splunk_hec,
    criblio_pipeline.normalize_and_label,
    criblio_pipeline.structure_repair,
    criblio_pipeline.volume_reduction,
    criblio_lookup_file.namespace_team_map,
    criblio_destination.new_relic,
    criblio_destination.s3_parquet,
    criblio_destination.cribl_lake,
    criblio_destination.output_router,
    criblio_routes.main_routes
  ]
}

resource "criblio_config_version" "pov_version" {
  group_id = criblio_group.cribl_o11y_pov.id
  message  = "O11y POV Configuration v1.0"

  depends_on = [
    criblio_commit.pov_commit
  ]
}

resource "criblio_deploy" "pov_deploy" {
  group_id              = criblio_group.cribl_o11y_pov.id
  message               = "O11y POV production deployment"
  config_version_id     = criblio_config_version.pov_version.id
  auto_activate         = true

  depends_on = [
    criblio_config_version.pov_version
  ]
}

output "commit_id" {
  description = "Configuration commit ID"
  value       = criblio_commit.pov_commit.id
}

output "config_version_id" {
  description = "Configuration version ID"
  value       = criblio_config_version.pov_version.id
}

output "deployment_id" {
  description = "Deployment ID"
  value       = criblio_deploy.pov_deploy.id
}

output "deployment_status" {
  description = "Deployment status"
  value       = criblio_deploy.pov_deploy.status
}
