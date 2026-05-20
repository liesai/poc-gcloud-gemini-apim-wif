output "apim_name" {
  description = "Nom de l'instance Azure API Management."
  value       = azurerm_api_management.this.name
}

output "resource_group_name" {
  description = "Resource group Azure cree par cette POC."
  value       = azurerm_resource_group.this.name
}

output "apim_principal_id" {
  description = "Object ID de la managed identity system-assigned APIM."
  value       = azurerm_api_management.this.identity[0].principal_id
}

output "apim_tenant_id" {
  description = "Tenant ID de la managed identity system-assigned APIM."
  value       = azurerm_api_management.this.identity[0].tenant_id
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
