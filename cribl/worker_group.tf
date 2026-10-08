resource "criblio_group" "demo-group-4" {
  id                   = "demo-group-4"
  product              = "stream"
  name                 = "demo-group-4"
  on_prem              = "false"
  is_fleet             = "false"
  worker_remote_access = "true"
  description          = "This is the worker group for the POV"

  cloud = {
    provider = "aws"
    region   = "us-west-2"
  }

  estimated_ingest_rate = "2048"
}
