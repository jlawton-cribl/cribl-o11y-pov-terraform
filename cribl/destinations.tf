# ========================================
# DAY 3: DESTINATIONS
# ========================================

resource "criblio_destination" "new_relic" {
  group_id       = criblio_group.cribl_o11y_pov.id
  destination_id = "new-relic-logs"
  description    = "New Relic log ingestion endpoint (demo-group-3 key)"

  content = jsonencode({
    id           = "new-relic-logs"
    type         = "newrelic"
    disabled     = false
    apiKey       = var.nr_api_key
    messageField = "message"
    batchSize    = 1000
    batchTimeout = "5s"
    tlsClientConfig = {
      insecureSkipVerify = false
      minVersion         = "1.2"
    }
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

resource "criblio_destination" "s3_parquet" {
  group_id       = criblio_group.cribl_o11y_pov.id
  destination_id = "s3-parquet-logs"
  description    = "S3 Parquet storage with gzip compression (demo-group-3 bucket)"

  content = jsonencode({
    id            = "s3-parquet-logs"
    type          = "output_s3"
    disabled      = false
    bucketName    = var.s3_bucket
    region        = var.s3_region
    prefix        = "gogen-demo"
    partitionPath = "gogen-demo/source_type/YYYY/MM/DD/HH"
    compression   = "gzip"
    format        = "parquet"
    batchSize     = 50
    batchTimeout  = "60s"
    s3ClientConfig = {
      sseAlgorithm = "AES256"
    }
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

resource "criblio_destination" "cribl_lake" {
  group_id       = criblio_group.cribl_o11y_pov.id
  destination_id = "cribl-lake-logs"
  description    = "Cribl Lake data archival"

  content = jsonencode({
    id           = "cribl-lake-logs"
    type         = "output_cribl_lake"
    disabled     = false
    endpoint     = var.lake_endpoint
    format       = "parquet"
    batchSize    = 100
    batchTimeout = "30s"
    tlsClientConfig = {
      insecureSkipVerify = false
      minVersion         = "1.2"
    }
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

resource "criblio_destination" "output_router" {
  group_id       = criblio_group.cribl_o11y_pov.id
  destination_id = "output-router"
  description    = "Smart output routing based on log levels and conditions"

  content = jsonencode({
    id       = "output-router"
    type     = "output_router"
    disabled = false

    routes = [
      {
        name   = "Route 1: Errors to New Relic"
        filter = "level === 'error' || level === 'fatal'"
        destinations = [
          {
            id       = "new-relic-logs"
            priority = 1
          }
        ]
      },
      {
        name   = "Route 2: Info and Debug to S3 and Lake"
        filter = "level === 'info' || level === 'debug'"
        destinations = [
          {
            id       = "s3-parquet-logs"
            priority = 1
          },
          {
            id       = "cribl-lake-logs"
            priority = 2
          }
        ]
      },
      {
        name   = "Route 3: Default to New Relic"
        filter = "true"
        destinations = [
          {
            id       = "new-relic-logs"
            priority = 3
          }
        ]
      }
    ]
  })

  depends_on = [
    criblio_group.cribl_o11y_pov,
    criblio_destination.new_relic,
    criblio_destination.s3_parquet,
    criblio_destination.cribl_lake
  ]
}

output "newrelic_destination_id" {
  description = "New Relic destination ID"
  value       = criblio_destination.new_relic.destination_id
}

output "s3_destination_id" {
  description = "S3 Parquet destination ID"
  value       = criblio_destination.s3_parquet.destination_id
}

output "lake_destination_id" {
  description = "Cribl Lake destination ID"
  value       = criblio_destination.cribl_lake.destination_id
}

output "router_destination_id" {
  description = "Output router destination ID"
  value       = criblio_destination.output_router.destination_id
}
