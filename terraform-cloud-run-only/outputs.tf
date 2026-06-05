output "project_id" {
  description = "Projet GCP cible."
  value       = var.project_id
}

output "service_name" {
  description = "Nom du service Cloud Run."
  value       = google_cloud_run_v2_service.api.name
}

output "service_url" {
  description = "URL Cloud Run."
  value       = google_cloud_run_v2_service.api.uri
}

output "image" {
  description = "Image Artifactory deployee par Cloud Run."
  value       = local.artifactory_image
}

output "artifactory_image" {
  description = "Image construite, poussee dans Artifactory et lue directement par Cloud Run."
  value       = local.artifactory_image
}

output "cloud_run_service_account" {
  description = "Service account utilise par Cloud Run."
  value       = local.run_service_account
}

output "gemini_default_model" {
  description = "Modele Gemini par defaut."
  value       = var.gemini_default_model
}

output "gemini_models" {
  description = "Modeles Gemini disponibilises a l'application."
  value       = var.gemini_models
}
