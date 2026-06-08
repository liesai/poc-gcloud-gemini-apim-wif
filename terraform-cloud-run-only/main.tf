locals {
  service_name       = var.service_name != null ? var.service_name : "${var.name_prefix}-api"
  cloud_run_image    = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}/${var.image_name}:${var.image_tag}"
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
    containers {
      image = local.cloud_run_image

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

}
