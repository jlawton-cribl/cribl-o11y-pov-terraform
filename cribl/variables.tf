variable "cribl_client_id" {
  description = "The client id used to access the Cribl API"
  type        = string
  sensitive   = true #only for secrets
}

variable "cribl_client_secret" {
  description = "The client secret variable used to access the Cribl API"
  type        = string
  sensitive   = true #only for secrets
}

variable "cribl_organization_id" {
  description = "The orginization id in Cribl cloud"
  type        = string
}

variable "cribl_workspace_id" {
  description = "The target workspace in the Cloud account"
  default     = "main"
}


