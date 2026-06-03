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

variable "create_user_assigned_identity" {
  description = "Cree et attache une user-assigned managed identity a APIM pour stabiliser l'identite utilisee vers Google WIF."
  type        = bool
  default     = false
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

variable "enable_client_sp_auth" {
  description = "Exige un token Entra ID client valide avant d'appeler le backend Cloud Run."
  type        = bool
  default     = false
}

variable "client_auth_tenant_id" {
  description = "Tenant ID Entra ID qui emet les tokens des service principals clients."
  type        = string
  default     = null
}

variable "client_auth_audience" {
  description = "Audience attendue dans le token client, par exemple api://<app-id-api-apim>."
  type        = string
  default     = null
}

variable "client_auth_allowed_roles" {
  description = "Roles applicatifs Entra ID autorises a appeler l'API APIM."
  type        = list(string)
  default     = []
}

variable "client_auth_roles_claim" {
  description = "Nom du claim portant les roles applicatifs dans le token client."
  type        = string
  default     = "roles"
}

variable "client_auth_allowed_app_ids" {
  description = "App IDs de service principals clients autorises. Preferer les roles applicatifs quand possible."
  type        = list(string)
  default     = []
}

variable "client_auth_app_id_claim" {
  description = "Nom du claim portant l'App ID client dans le token client. Utiliser azp pour les tokens v2, appid pour certains tokens v1."
  type        = string
  default     = "azp"
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
