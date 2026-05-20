variable "location" {
  description = "Region Azure ou deployer APIM."
  type        = string
  default     = "canadacentral"
}

variable "name_prefix" {
  description = "Prefixe des ressources Azure."
  type        = string
  default     = "poc-gemini"
}

variable "resource_group_name" {
  description = "Nom du resource group Azure. Si null, un nom est genere."
  type        = string
  default     = null
}

variable "apim_name" {
  description = "Nom globalement unique de l'instance Azure API Management. Si null, un nom est genere."
  type        = string
  default     = null
}

variable "publisher_name" {
  description = "Nom publie dans l'instance APIM."
  type        = string
  default     = "hamonrye"
}

variable "publisher_email" {
  description = "Email administrateur APIM."
  type        = string
}

variable "cloud_run_url" {
  description = "URL du service Cloud Run a exposer via APIM, par exemple la sortie Terraform GCP service_url."
  type        = string
}

variable "backend_api_key" {
  description = "Secret partage envoye par APIM vers Cloud Run dans le header X-Internal-Api-Key."
  type        = string
  default     = null
  sensitive   = true
}

variable "backend_auth_mode" {
  description = "Mode d'authentification APIM vers Cloud Run: shared_secret ou wif."
  type        = string
  default     = "shared_secret"

  validation {
    condition     = contains(["shared_secret", "wif"], var.backend_auth_mode)
    error_message = "backend_auth_mode doit valoir shared_secret ou wif."
  }
}

variable "google_sts_audience" {
  description = "Audience STS du provider Google Workload Identity Federation."
  type        = string
  default     = null
}

variable "google_service_account_email" {
  description = "Service account Google a impersonner via IAM Credentials."
  type        = string
  default     = null
}

variable "entra_wif_resource" {
  description = "Resource/audience Entra ID demandee par APIM pour le token WIF."
  type        = string
  default     = "api://AzureADTokenExchange"
}

variable "api_path" {
  description = "Chemin public de l'API dans APIM."
  type        = string
  default     = "gemini"
}

variable "subscription_required" {
  description = "Exige une subscription key APIM pour appeler l'API."
  type        = bool
  default     = false
}

variable "rate_limit_calls" {
  description = "Nombre d'appels autorises par fenetre de renouvellement APIM."
  type        = number
  default     = 30
}

variable "rate_limit_renewal_period" {
  description = "Fenetre de renouvellement du rate limit APIM, en secondes."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags Azure."
  type        = map(string)
  default = {
    workload = "poc-gcloud-gemini"
    managed  = "terraform"
  }
}
