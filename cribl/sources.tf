# ========================================
# DAY 1: SOURCES
# ========================================

# Splunk HEC Source Configuration
resource "criblio_source" "splunk_hec" {
  group_id  = criblio_group.cribl_o11y_pov.id
  source_id = "splunk-hec-input"

  type = "input_splunk_hec"

  content = jsonencode({
    type                  = "input_splunk_hec"
    listenOnIPAddress     = "0.0.0.0"
    port                  = 8088
    tlsEnabled            = true
    tlsMinVersion         = "1.3"
    socketTimeout         = 30000
    authToken             = var.hec_auth_token
    maxContentLength      = 10485760
    eventBreakerEnable    = true
    eventBreakerRegex     = "^\\{"
    eventBreakerToks      = 5
    acl = {
      readPrivilege = "public"
    }
  })

  depends_on = [
    criblio_group.cribl_o11y_pov
  ]
}
