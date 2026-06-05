locals {
  service_name       = var.service_name != null ? var.service_name : "${var.name_prefix}-api"
  artifactory_image  = "${var.artifactory_registry_url}/${var.image_name}:${var.image_tag}"
  effective_invokers = var.allow_unauthenticated ? setunion(var.invoker_members, ["allUsers"]) : var.invoker_members
  gemini_models_csv  = join(",", var.gemini_models)
  gemini_models_json = jsonencode(var.gemini_models)
}

resource "google_cloud_run_v2_service" "api" {
  project              = var.project_id
  name                 = local.service_name
  location             = var.region
  deletion_protection  = false
  invoker_iam_disabled = false
  labels               = var.labels

  template {
    service_account = var.service_account_email

    containers {
      image = local.artifactory_image

      ports {
        container_port = var.container_port
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }

      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.vertex_location
      }

      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "true"
      }

      env {
        name  = "GEMINI_MODEL"
        value = var.gemini_default_model
      }

      env {
        name  = "GEMINI_MODELS"
        value = local.gemini_models_csv
      }

      env {
        name  = "GEMINI_MODELS_JSON"
        value = local.gemini_models_json
      }

      dynamic "env" {
        for_each = var.enable_internal_api_key && var.internal_api_key != null ? [1] : []

        content {
          name  = "INTERNAL_API_KEY"
          value = var.internal_api_key
        }
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 0
        period_seconds        = 10
        timeout_seconds       = 3
        failure_threshold     = 6
      }
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }
  }

  lifecycle {
    precondition {
      condition     = var.service_account_email != null && var.service_account_email != ""
      error_message = "service_account_email est requis: le service account Cloud Run doit deja exister avec les roles necessaires."
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = local.effective_invokers
  project  = var.project_id
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = each.value
}
