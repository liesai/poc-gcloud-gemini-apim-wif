variable "project_id" {
  description = "Projet GCP existant dans lequel deployer Cloud Run."
  type        = string
}

variable "region" {
  description = "Region Cloud Run et Artifact Registry."
  type        = string
  default     = "us-central1"
}

variable "vertex_location" {
  description = "Location Vertex AI utilisee par l'application pour Gemini."
  type        = string
  default     = "global"
}

variable "name_prefix" {
  description = "Prefixe des ressources Cloud Run."
  type        = string
  default     = "gemini"
}

variable "service_name" {
  description = "Nom du service Cloud Run. Si null, utilise <name_prefix>-api."
  type        = string
  default     = null
}

variable "service_account_email" {
  description = "Service account existant a utiliser par Cloud Run. Si null et create_service_account=true, Terraform cree un service account."
  type        = string
  default     = null
}

variable "create_service_account" {
  description = "Cree un service account dedie a Cloud Run."
  type        = bool
  default     = true
}

variable "grant_vertex_user_role" {
  description = "Attribue roles/aiplatform.user au service account Cloud Run."
  type        = bool
  default     = true
}

variable "artifactory_registry_url" {
  description = "URL du registry Artifactory sans schema, par exemple artifactory.example.com/docker-local."
  type        = string
}

variable "image_name" {
  description = "Nom de l'image Docker dans Artifactory."
  type        = string
  default     = "gemini-api"
}

variable "artifact_remote_repository_id" {
  description = "Repository Artifact Registry remote utilise par Cloud Run pour lire Artifactory."
  type        = string
}

variable "create_artifact_remote_repository" {
  description = "Cree le repository Artifact Registry remote pointant vers Artifactory."
  type        = bool
  default     = false
}

variable "artifactory_username" {
  description = "Utilisateur Artifactory pour le repository remote Artifact Registry. Optionnel."
  type        = string
  default     = null
}

variable "artifactory_password_secret_version" {
  description = "Secret Manager version contenant le mot de passe Artifactory, par exemple projects/<project>/secrets/<secret>/versions/latest. Optionnel."
  type        = string
  default     = null
  sensitive   = true
}

variable "image_tag" {
  description = "Tag Docker a deployer. Le pipeline GitHub Actions le renseigne avec le SHA du commit."
  type        = string
}

variable "gemini_default_model" {
  description = "Modele Gemini utilise par defaut par l'application."
  type        = string
  default     = "gemini-2.5-flash-lite"
}

variable "gemini_models" {
  description = "Modeles Gemini a rendre disponibles a l'application Cloud Run."
  type        = list(string)
  default = [
    "gemini-3.5-flash",
    "gemini-2.5-flash",
    "gemini-3.1-flash",
    "gemini-2.5-flash-lite",
    "gemini-3-pro",
    "gemini-2.5-pro",
    "gemini-3.1-pro",
    "gemini-3-flash",
  ]
}

variable "allow_unauthenticated" {
  description = "Autorise l'invocation non authentifiee de Cloud Run. Mettre false si un LB/API Gateway/IAM invoker existe deja."
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "Membres IAM autorises a invoquer Cloud Run, par exemple serviceAccount:xxx@project.iam.gserviceaccount.com."
  type        = set(string)
  default     = []
}

variable "enable_internal_api_key" {
  description = "Expose INTERNAL_API_KEY a l'application pour une verification de header X-Internal-Api-Key."
  type        = bool
  default     = false
}

variable "internal_api_key" {
  description = "Secret partage optionnel entre le frontal existant et Cloud Run."
  type        = string
  default     = null
  sensitive   = true
}

variable "container_port" {
  description = "Port expose par le conteneur."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Limite CPU Cloud Run."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Limite memoire Cloud Run."
  type        = string
  default     = "512Mi"
}

variable "min_instance_count" {
  description = "Nombre minimal d'instances Cloud Run."
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Nombre maximal d'instances Cloud Run."
  type        = number
  default     = 2
}

variable "labels" {
  description = "Labels appliques aux ressources compatibles."
  type        = map(string)
  default = {
    workload = "gemini-cloud-run"
    managed  = "terraform"
  }
}
