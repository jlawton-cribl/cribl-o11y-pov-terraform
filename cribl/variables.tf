variable "cribl_client_id" {
  description = "The client id used to access the Cribl API"
  type        = string
  sensitive   = true
}

variable "cribl_client_secret" {
  description = "The client secret used to access the Cribl API"
  type        = string
  sensitive   = true
}

variable "cribl_organization_id" {
  description = "The organization id in Cribl cloud"
  type        = string
}

variable "cribl_workspace_id" {
  description = "The target workspace in the Cloud account"
  type        = string
  default     = "main"
}

variable "nr_api_key" {
  description = "New Relic ingest license key"
  type        = string
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket for log storage"
  type        = string
  default     = "cribl-o11y-pov-logs"
}

variable "s3_region" {
  description = "AWS region for S3"
  type        = string
  default     = "us-west-2"
}

variable "hec_auth_token" {
  description = "Splunk HEC authentication token"
  type        = string
  sensitive   = true
}


