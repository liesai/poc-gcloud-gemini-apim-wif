resource "random_id" "suffix" {
  byte_length = 3
}

resource "random_password" "internal_api_key" {
  length  = 40
  special = false
}

locals {
  project_id       = var.project_id != null ? var.project_id : "${var.name_prefix}-${random_id.suffix.hex}"
  app_dir          = abspath("${path.module}/../app")
  repository_id    = "${var.name_prefix}-repo"
  service_name     = "${var.name_prefix}-api"
  service_account  = "${var.name_prefix}-run"
  source_hash      = sha256(join("", [for file in sort(fileset(local.app_dir, "**")) : filesha256("${local.app_dir}/${file}")]))
  image            = "${var.region}-docker.pkg.dev/${local.project_id}/${local.repository_id}/${local.service_name}:${local.source_hash}"
  internal_api_key = var.internal_api_key != null ? var.internal_api_key : random_password.internal_api_key.result
}

resource "google_project" "this" {
  count           = var.create_project ? 1 : 0
  name            = local.project_id
  project_id      = local.project_id
  billing_account = var.billing_account_id
  deletion_policy = "DELETE"
  labels          = var.labels

  lifecycle {
    precondition {
      condition     = !var.create_project || var.billing_account_id != null
      error_message = "billing_account_id est requis quand create_project=true."
    }
  }
}

data "google_project" "effective" {
  project_id = local.project_id

  depends_on = [google_project.this]
}

resource "google_project_service" "services" {
  for_each = toset([
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])

  project            = local.project_id
  service            = each.key
  disable_on_destroy = true

  depends_on = [google_project.this]
}

resource "google_artifact_registry_repository" "app" {
  project       = local.project_id
  location      = var.region
  repository_id = local.repository_id
  description   = "Images Docker de la POC Gemini Cloud Run"
  format        = "DOCKER"
  labels        = var.labels

  depends_on = [google_project_service.services]
}

resource "google_service_account" "run" {
  project      = local.project_id
  account_id   = local.service_account
  display_name = "Cloud Run Gemini POC"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "apim_invoker" {
  count        = var.enable_azure_wif ? 1 : 0
  project      = local.project_id
  account_id   = "${var.name_prefix}-apim"
  display_name = "Azure APIM Cloud Run invoker"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "run_vertex_user" {
  project = local.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.run.email}"
}

resource "google_iam_workload_identity_pool" "azure_apim" {
  count                     = var.enable_azure_wif ? 1 : 0
  project                   = local.project_id
  workload_identity_pool_id = "${var.name_prefix}-azure"
  display_name              = "Azure APIM WIF"
  description               = "Federation Azure APIM Managed Identity pour appeler Cloud Run"
  disabled                  = false

  depends_on = [google_project_service.services]

  lifecycle {
    precondition {
      condition     = !var.enable_azure_wif || var.azure_tenant_id != null
      error_message = "azure_tenant_id est requis quand enable_azure_wif=true."
    }
  }
}

resource "google_iam_workload_identity_pool_provider" "azure_apim" {
  count                              = var.enable_azure_wif ? 1 : 0
  project                            = local.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.azure_apim[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "apim"
  display_name                       = "Azure APIM"
  disabled                           = false
  attribute_mapping = {
    "google.subject" = "assertion.oid"
  }
  attribute_condition = "assertion.oid == '${var.azure_apim_principal_id}'"

  oidc {
    issuer_uri        = "https://login.microsoftonline.com/${var.azure_tenant_id}/v2.0"
    allowed_audiences = [var.azure_wif_audience]
  }

  lifecycle {
    precondition {
      condition     = !var.enable_azure_wif || var.azure_apim_principal_id != null
      error_message = "azure_apim_principal_id est requis quand enable_azure_wif=true."
    }
  }
}

resource "google_service_account_iam_member" "apim_wif_user" {
  count              = var.enable_azure_wif ? 1 : 0
  service_account_id = google_service_account.apim_invoker[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${data.google_project.effective.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.azure_apim[0].workload_identity_pool_id}/subject/${var.azure_apim_principal_id}"
}

resource "google_cloud_run_v2_service_iam_member" "apim_invoker" {
  count    = var.enable_azure_wif ? 1 : 0
  project  = local.project_id
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.apim_invoker[0].email}"
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = local.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.effective.number}@cloudbuild.gserviceaccount.com"
}

resource "null_resource" "build_image" {
  triggers = {
    image       = local.image
    source_hash = local.source_hash
  }

  provisioner "local-exec" {
    command = "gcloud builds submit ${local.app_dir} --project ${local.project_id} --tag ${local.image}"
  }

  depends_on = [
    google_artifact_registry_repository.app,
    google_project_iam_member.cloudbuild_artifact_writer,
  ]
}

resource "google_cloud_run_v2_service" "api" {
  project              = local.project_id
  name                 = local.service_name
  location             = var.region
  deletion_protection  = false
  invoker_iam_disabled = false
  labels               = var.labels

  template {
    service_account = google_service_account.run.email

    containers {
      image = local.image

      ports {
        container_port = 8080
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = local.project_id
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
        value = var.gemini_model
      }

      dynamic "env" {
        for_each = var.enable_internal_api_key ? [1] : []

        content {
          name  = "INTERNAL_API_KEY"
          value = local.internal_api_key
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
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
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  depends_on = [
    null_resource.build_image,
    google_project_iam_member.run_vertex_user,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = local.project_id
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
