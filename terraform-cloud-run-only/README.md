# Deploiement Cloud Run uniquement avec Artifact Registry

Ce repertoire ajoute un deploiement GCP limite a Cloud Run avec une image poussee dans Artifact Registry. Il ne cree pas le projet, n'active pas les APIs, ne configure pas l'interconnect et ne configure pas de load balancer.

Le pipeline GitHub Actions peut creer le repository Artifact Registry, construit l'image Docker, la pousse dans Artifact Registry, puis deploie un service Cloud Run qui reference cette image.

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

Le service account Cloud Run doit deja etre gere par le socle. Ce module ne cree pas de service account et ne modifie pas son association; il se concentre sur le service Cloud Run et l'image Artifact Registry.

Si le repository Artifact Registry est deja livre par le socle, garder `create_artifact_registry_repository = false`. Sinon, le module peut le creer avec `create_artifact_registry_repository = true`.

## Pipeline GitHub Actions

Le workflow `.github/workflows/deploy-cloud-run.yml` est manuel. Il attend:

Secrets:

- `GCP_TERRAFORM_SA_KEY`

Variables:

- `GCP_PROJECT_ID`
- `GCP_REGION`
- `VERTEX_LOCATION`
- `ARTIFACT_REGISTRY_REPOSITORY_ID`
- `TF_STATE_BUCKET`
- `TF_STATE_PREFIX`

Variable optionnelle:

- `CREATE_ARTIFACT_REGISTRY_REPOSITORY` vaut `false` par defaut si absente.
