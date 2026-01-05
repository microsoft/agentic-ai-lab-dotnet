variable "region" {
  description = "Region to deploy resources to"
  default     =  "eastus2"
}

variable "tags" {
  description = "Tags to apply to Resource Group"
}

variable "deploy_content_understanding" {
  description = "Whether to deploy Content Understanding resources"
  type        = bool
  default     = true
}