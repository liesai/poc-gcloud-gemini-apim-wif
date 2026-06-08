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
  description = "Image Artifact Registry deployee par Cloud Run."
  value       = local.cloud_run_image
}

output "cloud_run_image" {
  description = "Image Artifact Registry lue par Cloud Run."
  value       = local.cloud_run_image
}

output "artifact_registry_repository" {
  description = "Repository Artifact Registry utilise."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}"
}

output "gemini_default_model" {
  description = "Modele Gemini par defaut."
  value       = var.gemini_default_model
}

output "gemini_models" {
  description = "Modeles Gemini disponibilises a l'application."
  value       = var.gemini_models
}
