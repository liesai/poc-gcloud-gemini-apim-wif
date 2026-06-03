output "apim_name" {
  description = "Nom de l'instance Azure API Management."
  value       = azurerm_api_management.this.name
}

output "resource_group_name" {
  description = "Resource group Azure cree par cette POC."
  value       = azurerm_resource_group.this.name
}

output "apim_principal_id" {
  description = "Object ID de l'identite APIM a autoriser cote Google WIF."
  value       = local.apim_invoker_principal_id
}

output "apim_tenant_id" {
  description = "Tenant ID de l'identite APIM a autoriser cote Google WIF."
  value       = local.apim_invoker_tenant_id
}

output "apim_system_assigned_principal_id" {
  description = "Object ID de la system-assigned managed identity APIM."
  value       = azurerm_api_management.this.identity[0].principal_id
}

output "apim_user_assigned_client_id" {
  description = "Client ID de la user-assigned managed identity APIM, si creee."
  value       = var.create_user_assigned_identity ? azurerm_user_assigned_identity.apim[0].client_id : null
}

output "apim_user_assigned_principal_id" {
  description = "Object ID de la user-assigned managed identity APIM, si creee."
  value       = var.create_user_assigned_identity ? azurerm_user_assigned_identity.apim[0].principal_id : null
}

output "gateway_url" {
  description = "URL publique du gateway APIM."
  value       = azurerm_api_management.this.gateway_url
}

output "gemini_status_url" {
  description = "Endpoint APIM pour le health check public."
  value       = "${azurerm_api_management.this.gateway_url}/${var.api_path}/status"
}

output "gemini_generate_url" {
  description = "Endpoint APIM pour appeler Gemini."
  value       = "${azurerm_api_management.this.gateway_url}/${var.api_path}/generate"
}

output "destroy_command" {
  description = "Commande de destruction de la partie Azure APIM."
  value       = "terraform -chdir=terraform-azure-apim destroy"
}
