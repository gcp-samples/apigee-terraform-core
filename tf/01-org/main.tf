locals {
  gcp_services = [
    "apigee.googleapis.com",
    "apihub.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "modelarmor.googleapis.com",
    "dlp.googleapis.com"
  ]

  is_drz          = var.drz_location != null && var.drz_location != "" && lower(var.drz_location) != "global"
  billing_type    = upper(var.billing_type) == "TRIAL" ? "EVALUATION" : upper(var.billing_type)
  apigee_endpoint = local.is_drz ? "https://${lower(var.drz_location)}-apigee.googleapis.com/v1/" : "https://apigee.googleapis.com/v1/"
}

provider "google" {
  project                = var.project_id
  region                 = var.region
  apigee_custom_endpoint = local.apigee_endpoint
}

/* Project APIs */

resource "google_project_service" "enabled_apis" {
  for_each           = toset(local.gcp_services)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

/* Apigee Organization (Protected from accidental deletion) */

resource "google_apigee_organization" "apigee_org" {
  project_id                 = var.project_id
  analytics_region           = var.region
  api_consumer_data_location = var.region
  disable_vpc_peering        = true
  runtime_type               = "CLOUD"
  billing_type               = local.billing_type
  depends_on                 = [google_project_service.enabled_apis]

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = !(local.is_drz && (upper(var.billing_type) == "TRIAL" || upper(var.billing_type) == "EVALUATION"))
      error_message = "Apigee TRIAL/EVALUATION billing type cannot be used when a DRZ location (drz_location) is specified. Please use PAYG or SUBSCRIPTION instead."
    }
  }
}
