variable "project_id" {
  description = "Project ID GCP. Si null, Terraform cree un projet poc-gemini-<suffix>."
  type        = string
  default     = null
}

variable "create_project" {
  description = "Cree le projet GCP. Mettre false pour utiliser un projet existant."
  type        = bool
  default     = true
}

variable "billing_account_id" {
  description = "Compte de facturation GCP, requis si create_project=true."
  type        = string
  default     = null
}

variable "region" {
  description = "Region Cloud Run et Artifact Registry."
  type        = string
  default     = "us-central1"
}

variable "vertex_location" {
  description = "Location Vertex AI pour Gemini."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Prefixe lisible pour les ressources."
  type        = string
  default     = "poc-gemini"
}

variable "gemini_model" {
  description = "Modele Gemini expose par l'API."
  type        = string
  default     = "gemini-2.5-flash-lite"
}

variable "gemini_models" {
  description = "Modeles Gemini autorises par l'API."
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
  description = "Expose Cloud Run publiquement. Pratique pour une POC; mettre false pour IAM only."
  type        = bool
  default     = true
}

variable "enable_internal_api_key" {
  description = "Active une verification de header X-Internal-Api-Key cote application."
  type        = bool
  default     = true
}

variable "internal_api_key" {
  description = "Secret partage optionnel entre APIM et Cloud Run. Si null, Terraform genere un secret."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_azure_wif" {
  description = "Active Workload Identity Federation pour permettre a Azure APIM Managed Identity d'appeler Cloud Run sans secret partage."
  type        = bool
  default     = false
}

variable "azure_tenant_id" {
  description = "Tenant ID Microsoft Entra de la managed identity APIM."
  type        = string
  default     = null
}

variable "azure_oidc_issuer_uri" {
  description = "Issuer OIDC du token Entra ID envoye a Google STS. Si null, utilise l'issuer v2 login.microsoftonline.com du tenant."
  type        = string
  default     = null
}

variable "azure_apim_principal_id" {
  description = "Object ID/principal ID de la managed identity APIM autorisee par WIF."
  type        = string
  default     = null
}

variable "azure_wif_audience" {
  description = "Audience presente dans le token Entra ID et acceptee par le provider WIF."
  type        = string
  default     = "api://AzureADTokenExchange"
}

variable "labels" {
  description = "Labels appliques aux ressources compatibles."
  type        = map(string)
  default = {
    workload = "poc-gcloud-gemini"
    managed  = "terraform"
  }
}
