# ========================================
# DAY 3: ROUTES
# ========================================

resource "criblio_routes" "main_routes" {
  group_id = criblio_group.cribl_o11y_pov.id

  content = jsonencode({
    routes = [
      {
        name   = "errors-to-newrelic"
        filter = "level === 'error' || level === 'fatal'"
        pipelineIds = [
          criblio_pipeline.normalize_and_label.pipeline_id
        ]
        destinationIds = [
          criblio_destination.new_relic.destination_id
        ]
        priority = 1
        disabled = false
      },
      {
        name   = "info-debug-to-s3-lake"
        filter = "level === 'info' || level === 'debug'"
        pipelineIds = [
          criblio_pipeline.volume_reduction.pipeline_id
        ]
        destinationIds = [
          criblio_destination.s3_parquet.destination_id,
          criblio_destination.cribl_lake.destination_id
        ]
        priority = 2
        disabled = false
      },
      {
        name   = "default-to-newrelic"
        filter = "true"
        pipelineIds = [
          criblio_pipeline.structure_repair.pipeline_id
        ]
        destinationIds = [
          criblio_destination.new_relic.destination_id
        ]
        priority = 3
        disabled = false
      }
    ]
  })

  depends_on = [
    criblio_group.cribl_o11y_pov,
    criblio_pipeline.normalize_and_label,
    criblio_pipeline.structure_repair,
    criblio_pipeline.volume_reduction,
    criblio_destination.new_relic,
    criblio_destination.s3_parquet,
    criblio_destination.cribl_lake
  ]
}

output "routes_configured" {
  description = "Routes configured and active"
  value = {
    route_1 = "errors-to-newrelic"
    route_2 = "info-debug-to-s3-lake"
    route_3 = "default-to-newrelic"
  }
}
