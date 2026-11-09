output "org_id" {
  description = "Apigee organization resource ID (organizations/<project_id>)."
  value       = google_apigee_organization.apigee_org.id
}

output "project_id" {
  description = "GCP Project ID."
  value       = var.project_id
}

output "region" {
  description = "GCP region."
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


output "lb_type" {
  description = "The type of load balancer configured ('none', 'ilb', or 'xlb')."
  value       = var.lb_type
}

output "lb_ip_address" {
  description = "The IP address reserved for the load balancer frontend (internal for ILB, external for XLB, null if none). Point your domain's DNS A record to this IP."
  value       = try(google_compute_address.apigee_lb_ip[0].address, null)
}

output "dns_a_record" {
  description = "DNS A record required to route domain traffic to the load balancer IP (null if lb_type is none). Both this A record and dns_authorization_record (CNAME) must be added in DNS."
  value = local.create_lb ? {
    name = "${trimsuffix(var.domain, ".")}."
    type = "A"
    data = google_compute_address.apigee_lb_ip[0].address
    note = "REQUIRED: Add BOTH this A record (routes traffic to LB) and the dns_authorization_record CNAME below (validates TLS cert) in your DNS provider."
  } : null
}

output "dns_authorization_record" {
  description = "DNS CNAME record required for the Certificate Manager TLS authorization challenge (null if lb_type is none). Both this CNAME record and dns_a_record (A) must be added in DNS."
  value       = try(google_certificate_manager_dns_authorization.apigee_dns_auth[0].dns_resource_record, null)
}

output "apigee_instance_id" {
  description = "The ID of the Apigee instance."
  value       = google_apigee_instance.apigee.id
}

output "apigee_service_attachment" {
  description = "The service attachment URI of the Apigee instance."
  value       = google_apigee_instance.apigee.service_attachment
}

output "network" {
  description = "The VPC network used for the load balancer (null if not configured)."
  value       = local.network
}

output "subnet" {
  description = "The subnetwork used for the load balancer (null if not configured)."
  value       = local.subnet
}
