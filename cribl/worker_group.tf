# ========================================
# DAY 1: WORKER GROUP
# ========================================

resource "criblio_group" "cribl_o11y_pov" {
  id                   = "demo-group-4"
  product              = "stream"
  name                 = "demo-group-4"
  on_prem              = false
  is_fleet             = false
  worker_remote_access = true
  description          = "Observability POV worker group for data normalization, repair, and reduction (demo-group-4)"

  cloud = {
    provider = "aws"
    region   = "us-west-2"
  }

  estimated_ingest_rate = 2048
}
