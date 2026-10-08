# ========================================
# DAY 1: WORKER GROUP
# ========================================

resource "criblio_group" "cribl_o11y_pov" {
  id                   = "cribl-o11y-pov"
  product              = "stream"
  name                 = "cribl-o11y-pov"
  on_prem              = false
  is_fleet             = false
  worker_remote_access = true
  description          = "Observability POV worker group for data normalization, repair, and reduction"

  cloud = {
    provider = "aws"
    region   = "us-west-2"
  }

  estimated_ingest_rate = 2048
}
