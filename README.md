# POC Google Cloud: Cloud Run + Vertex AI Gemini + Azure APIM

Cette POC deploie une petite API Python sur Google Cloud Run. L'API expose `POST /generate`, appelle Gemini via Vertex AI, puis retourne la reponse du modele.

La version validee expose l'API a travers Azure API Management. Cloud Run n'est pas public: APIM utilise sa managed identity Azure, l'echange via Google Workload Identity Federation, genere un ID token Google, puis appelle Cloud Run avec IAM.

Le deploiement est pilote par Terraform afin de pouvoir tout supprimer avec `terraform destroy`.

## Architecture

```mermaid
flowchart LR
  Client[curl ou app Python] --> APIM[Azure API Management<br/>Consumption]
  APIM --> Entra[Microsoft Entra ID<br/>Managed Identity token]
  APIM --> STS[Google Security Token Service<br/>Workload Identity Federation]
  APIM --> IAMCreds[Google IAM Credentials<br/>generateIdToken]
  APIM --> Run[Cloud Run prive<br/>FastAPI]
  Run --> Vertex[Vertex AI<br/>Gemini 2.5 Flash-Lite]

  TFGCP[Terraform GCP] --> Project[GCP project]
  TFGCP --> APIs[Google APIs]
  TFGCP --> AR[Artifact Registry]
  TFGCP --> Build[Cloud Build]
  TFGCP --> Run
  TFGCP --> WIF[Workload Identity Pool<br/>OIDC provider Azure]
  TFGCP --> GSA[Service account APIM invoker]

  TFAZ[Terraform Azure] --> RG[Azure Resource Group]
  TFAZ --> APIM
  TFAZ --> API[APIM API<br/>OpenAPI import]
  TFAZ --> Policy[APIM policy<br/>MI + STS + ID token]

  WIF --> GSA
  GSA --> Run
```

## Ressources deployees

GCP:

- un projet GCP dedie si `create_project=true`;
- les APIs Google Cloud: Cloud Run, Cloud Build, Artifact Registry, Vertex AI, IAM, IAM Credentials, STS et Service Usage;
- un repository Docker Artifact Registry;
- une image applicative construite par Cloud Build;
- un service account Cloud Run avec `roles/aiplatform.user`;
- un service Cloud Run prive avec `invoker_iam_disabled=false`;
- un service account Google dedie a APIM, autorise avec `roles/run.invoker`;
- un Workload Identity Pool et un provider OIDC Azure;
- une liaison `roles/iam.workloadIdentityUser` entre l'identite Azure APIM et le service account Google.

Azure:

- un Resource Group Azure dedie;
- une instance Azure API Management en SKU `Consumption_0`;
- une managed identity system-assigned sur APIM;
- une API APIM importee depuis une definition OpenAPI minimale;
- une policy APIM qui:
  - recupere un token Entra ID via managed identity;
  - l'echange contre un access token Google via STS;
  - appelle IAM Credentials `generateIdToken`;
  - envoie l'ID token Google a Cloud Run dans `Authorization: Bearer ...`.

Modele expose: `gemini-2.5-flash-lite`.

## Prerequis

Outils locaux:

```bash
gcloud --version
az version
terraform version
jq --version
curl --version
```

Authentification locale:

```bash
gcloud auth login
gcloud auth application-default login
az login
```

Un compte de facturation GCP actif est requis si Terraform cree le projet.

## Deploiement GCP

Configurer GCP:

```bash
cd /home/marc/poc-gcloud-gemini
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Configuration WIF validee pour cette POC:

```hcl
create_project     = true
billing_account_id = "XXXXXX-XXXXXX-XXXXXX"

region          = "us-central1"
vertex_location = "global"
gemini_model    = "gemini-2.5-flash-lite"

allow_unauthenticated    = false
enable_internal_api_key  = false
enable_azure_wif         = true
azure_tenant_id          = "<tenant-id>"
azure_apim_principal_id  = "<apim-managed-identity-principal-id>"
azure_wif_audience       = "<aud-claim-du-token-entra>"
```

Pour un premier passage, `azure_apim_principal_id` et `azure_wif_audience` ne sont connus qu'apres creation de l'APIM. Le workflow pratique est donc:

1. deployer GCP une premiere fois sans WIF complet si APIM n'existe pas encore;
2. deployer Azure APIM pour obtenir sa managed identity;
3. reporter `apim_principal_id`, `apim_tenant_id` et l'audience du token Entra dans `terraform/terraform.tfvars`;
4. reappliquer GCP pour creer le provider WIF et fermer Cloud Run au public.

Commandes GCP:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Dans cette session, le projet valide est `poc-gemini-c8ef93` et Cloud Run refuse les appels directs non authentifies avec `403`.

## Deploiement Azure APIM

Preparer les variables:

```bash
cp terraform-azure-apim/terraform.tfvars.example terraform-azure-apim/terraform.tfvars
```

Variables principales:

```hcl
publisher_email  = "vous@example.com"
cloud_run_url    = "https://poc-gemini-api-xxxxx-uc.a.run.app"
backend_auth_mode = "wif"
```

Apres creation de la managed identity APIM, recuperer les outputs:

```bash
terraform -chdir=terraform-azure-apim output -raw apim_principal_id
terraform -chdir=terraform-azure-apim output -raw apim_tenant_id
```

Pour appliquer la policy WIF:

```bash
terraform -chdir=terraform-azure-apim init

terraform -chdir=terraform-azure-apim apply \
  -var='backend_auth_mode=wif' \
  -var="google_sts_audience=$(terraform -chdir=terraform output -raw azure_wif_provider_audience)" \
  -var="google_service_account_email=$(terraform -chdir=terraform output -raw apim_invoker_service_account)"
```

Endpoints APIM:

```text
https://apim-poc-gemini-k6hh7b.azure-api.net/gemini/status
https://apim-poc-gemini-k6hh7b.azure-api.net/gemini/generate
```

## Deploiement Cloud Run seul avec Artifactory

Un module separe est disponible dans `terraform-cloud-run-only/` pour deployer uniquement Cloud Run dans un socle GCP deja livre. Il ne cree pas le projet, n'active pas les APIs, ne configure pas l'interconnect et ne configure pas de load balancer.

Le flux cible est:

1. GitHub Actions construit l'image Docker depuis `app/`;
2. l'image est poussee dans Artifactory;
3. Cloud Run lit cette image via un repository Artifact Registry remote pointant vers Artifactory;
4. Terraform applique uniquement le service Cloud Run, son service account optionnel, les invokers IAM optionnels et les variables Gemini.

Modeles Gemini disponibilises:

```text
gemini-3.5-flash
gemini-2.5-flash
gemini-3.1-flash
gemini-2.5-flash-lite
gemini-3-pro
gemini-2.5-pro
gemini-3.1-pro
gemini-3-flash
```

L'API accepte maintenant un champ optionnel `model` sur `POST /generate`. Si le champ est absent, elle utilise `GEMINI_MODEL`. Si le modele demande n'est pas dans `GEMINI_MODELS`, l'API retourne `400`.

Exemple:

```bash
curl -sS \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Resume ce besoin en une phrase.","model":"gemini-2.5-flash"}' \
  "$URL/generate" | jq .
```

### Variables Terraform principales

Exemple de configuration:

```hcl
project_id = "mon-projet-gcp"

region          = "us-central1"
vertex_location = "global"

service_name = "gemini-api"

artifactory_registry_url      = "artifactory.example.com/docker-local"
image_name                    = "gemini-api"
image_tag                     = "a-remplacer-par-le-sha"
artifact_remote_repository_id = "artifactory-remote"

create_artifact_remote_repository = false
create_service_account            = true
grant_vertex_user_role            = true

allow_unauthenticated = false
invoker_members = [
  # "serviceAccount:frontal-invoker@mon-projet-gcp.iam.gserviceaccount.com",
]
```

Le backend Terraform est GCS. En local ou dans CI, fournir un fichier `backend.hcl` non versionne:

```hcl
bucket = "mon-bucket-tfstate"
prefix = "poc-gcloud-gemini/cloud-run"
```

Commandes locales:

```bash
terraform -chdir=terraform-cloud-run-only init -backend-config=backend.hcl
terraform -chdir=terraform-cloud-run-only plan
terraform -chdir=terraform-cloud-run-only apply
```

### Pipeline GitHub Actions

Le workflow manuel `.github/workflows/deploy-cloud-run.yml` fait:

- authentification GCP via Workload Identity Federation;
- login Docker sur Artifactory;
- build et push de l'image;
- `terraform init`, `validate`, puis `apply` sur `terraform-cloud-run-only/`.

Secrets GitHub requis:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_SERVICE_ACCOUNT
ARTIFACTORY_USERNAME
ARTIFACTORY_PASSWORD
```

Variables GitHub requises:

```text
GCP_PROJECT_ID
GCP_REGION
VERTEX_LOCATION
ARTIFACTORY_REGISTRY_URL
ARTIFACT_REMOTE_REPOSITORY_ID
TF_STATE_BUCKET
TF_STATE_PREFIX
```

Le workflow se lance manuellement depuis GitHub Actions. Par defaut, le tag image est le SHA du commit; il peut etre surcharge par l'input `image_tag`.

## Tests

Se placer dans le repertoire de la POC:

```bash
cd /home/marc/poc-gcloud-gemini
```

URLs APIM actuellement deployeees:

```text
https://apim-poc-gemini-k6hh7b.azure-api.net/gemini/status
https://apim-poc-gemini-k6hh7b.azure-api.net/gemini/generate
```

Verifier que Cloud Run direct est refuse:

```bash
URL="$(terraform -chdir=terraform output -raw service_url)"

curl -sS -o /tmp/direct -w '%{http_code}\n' \
  -H "Content-Type: application/json" \
  -d '{"prompt":"direct","model":"gemini-2.5-flash-lite"}' \
  "$URL/generate"
```

Resultat attendu en mode WIF prive: `403`.

Tester le statut via APIM:

```bash
curl -sS "$(terraform -chdir=terraform-azure-apim output -raw gemini_status_url)" | jq .
```

Resultat attendu:

```json
{
  "status": "ok",
  "model": "gemini-2.5-flash-lite",
  "location": "global"
}
```

Tester la generation via APIM avec le script:

```bash
./scripts/call_apim.sh \
  "Reponds en francais en une phrase: valide le chemin APIM Managed Identity vers Cloud Run." \
  "gemini-2.5-flash-lite"
```

Equivalent manuel:

```bash
APIM_URL="$(terraform -chdir=terraform-azure-apim output -raw gemini_generate_url)"

curl -sS \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Reponds en francais en une phrase: valide le workflow APIM vers Cloud Run prive via WIF.","model":"gemini-2.5-flash-lite"}' \
  "$APIM_URL" | jq .
```

Resultat attendu: `200 OK` avec un JSON contenant `model`, `location` et `text`.

Tester explicitement la selection dynamique avec un autre modele autorise:

```bash
./scripts/call_apim.sh \
  "Reponds en francais en une phrase: valide le choix dynamique du modele." \
  "gemini-2.5-flash"
```

## Alternative: secret partage

Le module Azure APIM garde un mode de repli `shared_secret`. Dans ce mode:

- Cloud Run reste public au sens IAM;
- l'application FastAPI exige `X-Internal-Api-Key`;
- APIM injecte ce header vers le backend.

Ce mode est plus simple pour une POC rapide, mais moins propre qu'une federation d'identite. Pour l'activer:

```hcl
backend_auth_mode = "shared_secret"
backend_api_key   = "secret-partage"
```

Et cote GCP:

```hcl
allow_unauthenticated   = true
enable_internal_api_key = true
enable_azure_wif        = false
```

## Disponibiliser l'API a plusieurs clients

Pour exposer cette API a plusieurs consommateurs, APIM doit devenir le point de controle client:

- creer un produit APIM par usage: `internal`, `partner`, `sandbox`, `production`;
- activer `subscription_required=true` pour forcer une subscription key APIM par client ou application;
- associer chaque client a un produit APIM distinct;
- appliquer des quotas par produit ou par subscription;
- ajouter du rate limiting par subscription plutot que par IP;
- journaliser `context.Subscription.Id`, `context.User.Id` et un identifiant applicatif;
- exposer des chemins versionnes comme `/gemini/v1/generate`;
- separer les environnements avec des APIM/API distincts ou des revisions APIM;
- definir un contrat OpenAPI stable et importer les versions dans APIM;
- ajouter une policy de validation de payload si le schema devient plus strict;
- utiliser des Named Values APIM ou Key Vault pour les parametres sensibles si un secret reste necessaire;
- garder Cloud Run prive et n'autoriser que le service account Google impersonne par APIM.

Flux recommande pour un nouveau client:

1. creer ou choisir un produit APIM;
2. creer une subscription client;
3. appliquer quota/rate limit sur ce produit ou cette subscription;
4. fournir uniquement l'URL APIM et la subscription key, jamais l'URL Cloud Run;
5. suivre la consommation dans les logs APIM et Cloud Logging;
6. revoquer le client en supprimant ou suspendant sa subscription.

## Desinstallation

Detruire Azure APIM:

```bash
terraform -chdir=terraform-azure-apim destroy
```

Detruire GCP:

```bash
terraform -chdir=terraform destroy
```

Si `create_project=true`, Terraform detruit le projet GCP gere par cette POC.

## Bonnes pratiques appliquees

- Cloud Run n'est pas expose publiquement en mode WIF.
- APIM utilise une managed identity, sans secret long terme pour appeler Cloud Run.
- Google STS emet un access token court via Workload Identity Federation.
- IAM Credentials genere un ID token court pour Cloud Run.
- Le service account Google impersonne par APIM n'a que `roles/run.invoker`.
- L'application Cloud Run utilise son propre service account pour Vertex AI avec `roles/aiplatform.user`.
- Les states Terraform GCP et Azure sont separes pour detruire APIM sans toucher GCP.
- `min_instance_count=0` limite le cout idle de la POC.

## References

- Gemini 2.5 Flash-Lite: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash-lite
- Google Gen AI SDK: https://cloud.google.com/vertex-ai/generative-ai/docs/sdks/overview
- Cloud Run authentication: https://cloud.google.com/run/docs/authenticating/service-to-service
- Workload Identity Federation: https://cloud.google.com/iam/docs/workload-identity-federation
- Azure API Management managed identity policy: https://learn.microsoft.com/en-us/azure/api-management/authentication-managed-identity-policy
- Azure API Management avec Terraform: https://learn.microsoft.com/en-us/azure/api-management/quickstart-terraform
