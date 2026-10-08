terraform {
  required_providers {
    criblio = {
      source  = "criblio/criblio"
      version = ">= 0.1.0"
    }
  }
}

provider "criblio" {
  client_id       = var.cribl_client_id
  client_secret   = var.cribl_client_secret
  organization_id = var.cribl_organization_id
  workspace_id    = var.cribl_workspace_id
}


