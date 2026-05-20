output "project_id" {
  description = "Projet GCP utilise par la POC."
  value       = local.project_id
}

output "service_url" {
  description = "URL Cloud Run de l'API Gemini."
  value       = google_cloud_run_v2_service.api.uri
}

output "image" {
  description = "Image deployee sur Cloud Run."
  value       = local.image
}

output "destroy_command" {
  description = "Commande de destruction de la POC."
  value       = "terraform -chdir=terraform destroy"
}

output "apim_backend_api_key" {
  description = "Secret a fournir au module Azure APIM pour appeler Cloud Run."
  value       = local.internal_api_key
  sensitive   = true
}

output "azure_wif_provider_audience" {
  description = "Audience Google STS pour le provider Workload Identity Federation Azure APIM."
  value       = var.enable_azure_wif ? "//iam.googleapis.com/projects/${data.google_project.effective.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.azure_apim[0].workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.azure_apim[0].workload_identity_pool_provider_id}" : null
}

output "apim_invoker_service_account" {
  description = "Service account Google impersonne par APIM via WIF."
  value       = var.enable_azure_wif ? google_service_account.apim_invoker[0].email : null
}

output "azure_wif_audience" {
  description = "Audience Entra ID a demander depuis APIM."
  value       = var.azure_wif_audience
}
