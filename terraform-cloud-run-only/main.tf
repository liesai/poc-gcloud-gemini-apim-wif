locals {
  service_name        = var.service_name != null ? var.service_name : "${var.name_prefix}-api"
  service_account_id  = "${var.name_prefix}-run"
  artifactory_image   = "${var.artifactory_registry_url}/${var.image_name}:${var.image_tag}"
  cloud_run_image     = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_remote_repository_id}/${var.image_name}:${var.image_tag}"
  run_service_account = var.service_account_email != null ? var.service_account_email : try(google_service_account.run[0].email, null)
  effective_invokers  = var.allow_unauthenticated ? setunion(var.invoker_members, ["allUsers"]) : var.invoker_members
  gemini_models_csv   = join(",", var.gemini_models)
  gemini_models_json  = jsonencode(var.gemini_models)
}

resource "google_artifact_registry_repository" "artifactory_remote" {
  count         = var.create_artifact_remote_repository ? 1 : 0
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_remote_repository_id
  description   = "Remote Docker repository Artifactory pour Cloud Run Gemini"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  labels        = var.labels

  remote_repository_config {
    description = "Artifactory"

    docker_repository {
      custom_repository {
        uri = "https://${var.artifactory_registry_url}"
      }
    }

    dynamic "upstream_credentials" {
      for_each = var.artifactory_username != null && var.artifactory_password_secret_version != null ? [1] : []

      content {
        username_password_credentials {
          username                = var.artifactory_username
          password_secret_version = var.artifactory_password_secret_version
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = (var.artifactory_username == null && var.artifactory_password_secret_version == null) || (var.artifactory_username != null && var.artifactory_password_secret_version != null)
      error_message = "artifactory_username et artifactory_password_secret_version doivent etre renseignes ensemble."
    }
  }
}

resource "google_service_account" "run" {
  count        = var.create_service_account && var.service_account_email == null ? 1 : 0
  project      = var.project_id
  account_id   = local.service_account_id
  display_name = "Cloud Run Gemini"
}

resource "google_project_iam_member" "run_vertex_user" {
  count   = var.grant_vertex_user_role && local.run_service_account != null ? 1 : 0
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${local.run_service_account}"
}

resource "google_cloud_run_v2_service" "api" {
  project              = var.project_id
  name                 = local.service_name
  location             = var.region
  deletion_protection  = false
  invoker_iam_disabled = false
  labels               = var.labels

  template {
    service_account = local.run_service_account

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

  depends_on = [
    google_artifact_registry_repository.artifactory_remote,
    google_project_iam_member.run_vertex_user,
  ]

  lifecycle {
    precondition {
      condition     = local.run_service_account != null
      error_message = "service_account_email est requis quand create_service_account=false."
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
