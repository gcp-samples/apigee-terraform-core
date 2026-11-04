variable "project_id" {
  description = "Project id (also used for the Apigee Organization)."
  type        = string
}

variable "region" {
  description = "GCP region for the Apigee analytics & consumer data location."
  type        = string
}

variable "drz_location" {
  description = "The DRZ location to use for deploying Apigee, either 'eu', 'us', 'in', or empty/null for global."
  type        = string
  default     = null
}

variable "billing_type" {
  description = "The Apigee billing type: 'PAYG' (default), 'TRIAL' (or 'EVALUATION', only valid for global), or 'SUBSCRIPTION'."
  type        = string
  default     = "PAYG"

  validation {
    condition     = contains(["PAYG", "TRIAL", "EVALUATION", "SUBSCRIPTION"], upper(var.billing_type))
    error_message = "Allowed values for billing_type are 'PAYG', 'TRIAL', 'EVALUATION', or 'SUBSCRIPTION'."
  }
}

