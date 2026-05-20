resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : "rg-${var.name_prefix}-${random_string.suffix.result}"
  apim_name           = var.apim_name != null ? var.apim_name : "apim-${var.name_prefix}-${random_string.suffix.result}"
  cloud_run_url       = trimsuffix(var.cloud_run_url, "/")
  policy_xml = var.backend_auth_mode == "wif" ? templatefile("${path.module}/policy-wif.xml.tftpl", {
    cloud_run_url                = local.cloud_run_url
    entra_wif_resource           = var.entra_wif_resource
    google_sts_audience          = var.google_sts_audience
    google_sts_audience_encoded  = urlencode(var.google_sts_audience)
    google_service_account_email = var.google_service_account_email
    }) : templatefile("${path.module}/policy-shared-secret.xml.tftpl", {
    cloud_run_url   = local.cloud_run_url
    backend_api_key = var.backend_api_key
  })
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_api_management" "this" {
  name                = local.apim_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Consumption_0"
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_api_management_api" "gemini" {
  name                  = "gemini-poc"
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = "Gemini POC"
  path                  = var.api_path
  protocols             = ["https"]
  service_url           = local.cloud_run_url
  subscription_required = var.subscription_required

  import {
    content_format = "openapi+json"
    content_value = templatefile("${path.module}/openapi.json.tftpl", {
      title = "Gemini POC"
    })
  }
}

resource "azurerm_api_management_api_policy" "gemini" {
  api_name            = azurerm_api_management_api.gemini.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name

  xml_content = local.policy_xml

  lifecycle {
    precondition {
      condition     = var.backend_auth_mode != "shared_secret" || var.backend_api_key != null
      error_message = "backend_api_key est requis quand backend_auth_mode=shared_secret."
    }
    precondition {
      condition     = var.backend_auth_mode != "wif" || (var.google_sts_audience != null && var.google_service_account_email != null)
      error_message = "google_sts_audience et google_service_account_email sont requis quand backend_auth_mode=wif."
    }
  }
}
