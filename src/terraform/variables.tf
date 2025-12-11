variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "project_number" {
  description = "The Google Cloud Project number"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP zone to apply this config to"
  default     = "us-central1-a"
}

variable "ranger_pwd" {
  type        = string
  description = "The admin password of Ranger in Legacy Hadoop cluster"
  default     = "ChangeMe123!" 
}

