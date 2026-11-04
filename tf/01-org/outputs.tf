output "org_id" {
  description = "Apigee organization resource ID (organizations/<project_id>)."
  value       = google_apigee_organization.apigee_org.id
}

output "project_id" {
  description = "GCP Project ID."
  value       = var.project_id
}

output "region" {
  description = "Analytics and consumer data region."
  value       = var.region
}

output "drz_location" {
  description = "The DRZ location configured for Apigee (or null for global)."
  value       = var.drz_location
}

output "billing_type" {
  description = "Apigee billing type."
  value       = local.billing_type
}

output "apigee_custom_endpoint" {
  description = "The Apigee API endpoint used."
  value       = local.apigee_endpoint
}

