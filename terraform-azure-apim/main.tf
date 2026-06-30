resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : "rg-${var.name_prefix}-${random_string.suffix.result}"
  apim_name           = var.apim_name != null ? var.apim_name : "apim-${var.name_prefix}-${random_string.suffix.result}"
  cloud_run_url       = trimsuffix(var.cloud_run_url, "/")
  client_auth_policy = templatefile("${path.module}/policy-client-auth.xml.tftpl", {
    enable_client_sp_auth       = var.enable_client_sp_auth
    client_auth_tenant_id       = var.client_auth_tenant_id
    client_auth_audience        = var.client_auth_audience
    client_auth_allowed_roles   = var.client_auth_allowed_roles
    client_auth_roles_claim     = var.client_auth_roles_claim
    client_auth_allowed_app_ids = var.client_auth_allowed_app_ids
    client_auth_app_id_claim    = var.client_auth_app_id_claim
  })
  model_policy = templatefile("${path.module}/policy-model-allowlist.xml.tftpl", {
    allowed_models       = var.allowed_gemini_models
    allowed_models_guard = join("|", concat([""], var.allowed_gemini_models, [""]))
  })
  apim_wif_managed_identity_client_id = var.create_user_assigned_identity ? azurerm_user_assigned_identity.apim[0].client_id : null
  apim_invoker_principal_id           = var.create_user_assigned_identity ? azurerm_user_assigned_identity.apim[0].principal_id : azurerm_api_management.this.identity[0].principal_id
  apim_invoker_tenant_id              = var.create_user_assigned_identity ? azurerm_user_assigned_identity.apim[0].tenant_id : azurerm_api_management.this.identity[0].tenant_id
  policy_xml = var.backend_auth_mode == "wif" ? templatefile("${path.module}/policy-wif.xml.tftpl", {
    cloud_run_url                       = local.cloud_run_url
    client_auth_policy                  = local.client_auth_policy
    model_policy                        = local.model_policy
    entra_wif_resource                  = var.entra_wif_resource
    google_sts_audience                 = var.google_sts_audience
    google_sts_audience_encoded         = urlencode(var.google_sts_audience)
    google_service_account_email        = var.google_service_account_email
    apim_wif_managed_identity_client_id = local.apim_wif_managed_identity_client_id
    }) : templatefile("${path.module}/policy-shared-secret.xml.tftpl", {
    cloud_run_url      = local.cloud_run_url
    client_auth_policy = local.client_auth_policy
    model_policy       = local.model_policy
    backend_api_key    = var.backend_api_key
  })
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "apim" {
  count               = var.create_user_assigned_identity ? 1 : 0
  name                = "${local.apim_name}-mi"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
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
    type         = var.create_user_assigned_identity ? "SystemAssigned, UserAssigned" : "SystemAssigned"
    identity_ids = var.create_user_assigned_identity ? [azurerm_user_assigned_identity.apim[0].id] : null
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
    precondition {
      condition     = !var.enable_client_sp_auth || (var.client_auth_tenant_id != null && var.client_auth_audience != null)
      error_message = "client_auth_tenant_id et client_auth_audience sont requis quand enable_client_sp_auth=true."
    }
    precondition {
      condition     = !var.enable_client_sp_auth || length(var.client_auth_allowed_roles) > 0 || length(var.client_auth_allowed_app_ids) > 0
      error_message = "Au moins un role ou un app ID client doit etre autorise quand enable_client_sp_auth=true."
    }
  }
}
