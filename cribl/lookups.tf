# ========================================
# DAY 2: LOOKUPS
# ========================================

resource "criblio_lookup_file" "namespace_team_map" {
  group_id     = criblio_group.cribl_o11y_pov.id
  lookup_id    = "namespace-team-mapping"
  description  = "Map Kubernetes namespaces to team names and service tiers"

  content = file("${path.module}/data/namespace_team_map.csv")

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}

output "lookup_file_id" {
  description = "Namespace to team mapping lookup file ID"
  value       = criblio_lookup_file.namespace_team_map.lookup_id
}
