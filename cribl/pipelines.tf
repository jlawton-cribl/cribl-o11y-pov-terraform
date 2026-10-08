# ========================================
# DAY 2: PIPELINES
# ========================================

# Pipeline 1: Normalize and Label
resource "criblio_pipeline" "normalize_and_label" {
  group_id    = criblio_group.cribl_o11y_pov.id
  pipeline_id = "normalize-and-label"
  description = "Day 1: Normalize field names, add labels, flatten structure"

  content = jsonencode({
    id          = "normalize-and-label"
    description = "Normalize field names, add labels, flatten structure"
    disabled    = false
    functions = [
      {
        id       = "normalize_eval"
        type     = "eval"
        disabled = false
        conf = {
          add = [
            "level = severity || msg != null ? severity : 'unknown'",
            "message = msg || message",
            "src = source || src"
          ]
        }
      },
      {
        id       = "namespace_lookup"
        type     = "lookup"
        disabled = false
        conf = {
          lookupTableId = "namespace-team-mapping"
          matchType     = "exactMatch"
          matchFields = {
            namespace = "namespace"
          }
          outputFields = {
            team         = "team"
            service_tier = "service_tier"
          }
          preserveNullMatch = true
        }
      },
      {
        id       = "tag_missing_labels"
        type     = "eval"
        disabled = false
        conf = {
          add = [
            "team = team || 'unknown-team'",
            "__source_type = typeof(msg) === 'object' ? 'json' : 'text'",
            "__missing_labels = !namespace ? 'true' : 'false'"
          ]
        }
      }
    ]
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

# Pipeline 2: Structure Repair
resource "criblio_pipeline" "structure_repair" {
  group_id    = criblio_group.cribl_o11y_pov.id
  pipeline_id = "structure-repair"
  description = "Day 2: Extract severity from text logs, parse multi-line traces, normalize timestamps"

  content = jsonencode({
    id          = "structure-repair"
    description = "Extract severity from text logs, parse multi-line traces, normalize timestamps"
    disabled    = false
    functions = [
      {
        id       = "extract_severity"
        type     = "regex"
        disabled = false
        conf = {
          source  = "message"
          pattern = "(?i)(ERROR|WARN|INFO|DEBUG|FATAL|TRACE)"
          outputFields = {
            level = "$1"
          }
        }
      },
      {
        id       = "parse_multiline_json"
        type     = "serde"
        disabled = false
        conf = {
          source = "message"
          mode   = "parse"
          type   = "json"
        }
      },
      {
        id       = "normalize_timestamp_level"
        type     = "eval"
        disabled = false
        conf = {
          add = [
            "_time = isNumber(_time) ? _time : strptime(timestamp, '%Y-%m-%dT%H:%M:%SZ')",
            "level = upper(level) === 'WARN' ? 'warning' : upper(level)",
            "level = ['ERROR', 'FATAL'].indexOf(upper(level)) !== -1 ? 'error' : level"
          ]
        }
      }
    ]
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

# Pipeline 3: Volume Reduction
resource "criblio_pipeline" "volume_reduction" {
  group_id    = criblio_group.cribl_o11y_pov.id
  pipeline_id = "volume-reduction"
  description = "Day 2: Filter low-value logs, apply sampling, remove empty messages"

  content = jsonencode({
    id          = "volume-reduction"
    description = "Filter low-value logs, apply sampling, remove empty messages"
    disabled    = false
    functions = [
      {
        id       = "drop_debug_in_prod"
        type     = "drop"
        disabled = false
        conf = {
          filter = "level === 'DEBUG' && environment === 'prod'"
        }
      },
      {
        id       = "logarithmic_sampling"
        type     = "sample"
        disabled = false
        conf = {
          mode    = "logarithmic"
          factor  = 10
          groupBy = ["appId", "namespace"]
        }
      },
      {
        id       = "drop_empty_messages"
        type     = "drop"
        disabled = false
        conf = {
          filter = "!message || message === ''"
        }
      }
    ]
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

output "normalize_pipeline_id" {
  description = "Normalize and label pipeline ID"
  value       = criblio_pipeline.normalize_and_label.pipeline_id
}

output "repair_pipeline_id" {
  description = "Structure repair pipeline ID"
  value       = criblio_pipeline.structure_repair.pipeline_id
}

output "reduce_pipeline_id" {
  description = "Volume reduction pipeline ID"
  value       = criblio_pipeline.volume_reduction.pipeline_id
}
