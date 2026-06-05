# Deploiement Cloud Run uniquement avec Artifactory

Ce repertoire ajoute un deploiement GCP limite a Cloud Run avec une image Artifactory referencee directement. Il ne cree pas le projet, n'active pas les APIs, ne cree pas d'Artifact Registry, ne configure pas l'interconnect et ne configure pas de load balancer.

Le pipeline GitHub Actions construit l'application `../app` avec Docker, pousse l'image dans Artifactory, puis Terraform deploie un service Cloud Run qui reference directement l'image Artifactory.

## Modeles declares

Les modeles sont fournis a Cloud Run via `GEMINI_MODELS` et `GEMINI_MODELS_JSON`:

- `gemini-3.5-flash`
- `gemini-2.5-flash`
- `gemini-3.1-flash`
- `gemini-2.5-flash-lite`
- `gemini-3-pro`
- `gemini-2.5-pro`
- `gemini-3.1-pro`
- `gemini-3-flash`

Le modele par defaut reste configurable par `gemini_default_model`. L'API accepte aussi un champ optionnel `model` sur `POST /generate`; il doit faire partie de cette liste.

## Utilisation

```bash
cd /home/marc/poc-gcloud-gemini
cp terraform-cloud-run-only/terraform.tfvars.example terraform-cloud-run-only/terraform.tfvars
terraform -chdir=terraform-cloud-run-only init -backend-config=backend.hcl
terraform -chdir=terraform-cloud-run-only plan
terraform -chdir=terraform-cloud-run-only apply
```

Le fichier `backend.hcl` doit pointer vers un bucket GCS existant:

```hcl
bucket = "mon-bucket-tfstate"
prefix = "poc-gcloud-gemini/cloud-run"
```

Le service account Cloud Run doit deja etre livre par le socle avec les roles necessaires. Terraform se contente de l'associer au service Cloud Run via `service_account_email`.

## Pipeline GitHub Actions

Le workflow `.github/workflows/deploy-cloud-run.yml` est manuel. Il attend:

Secrets:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `ARTIFACTORY_USERNAME`
- `ARTIFACTORY_PASSWORD`

Variables:

- `GCP_PROJECT_ID`
- `GCP_REGION`
- `VERTEX_LOCATION`
- `ARTIFACTORY_REGISTRY_URL`
- `CLOUD_RUN_SERVICE_ACCOUNT_EMAIL`
- `TF_STATE_BUCKET`
- `TF_STATE_PREFIX`
