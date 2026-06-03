#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"
PROMPT="${1:-Reponds en une phrase: pourquoi Cloud Run convient bien a une POC Gemini ?}"
MODEL="${2:-gemini-2.5-flash-lite}"

URL="$(terraform -chdir="$TF_DIR" output -raw service_url)"
INTERNAL_API_KEY="$(terraform -chdir="$TF_DIR" output -raw apim_backend_api_key 2>/dev/null || true)"

HEADERS=(-H "Content-Type: application/json")
if [[ -n "$INTERNAL_API_KEY" ]]; then
  HEADERS+=(-H "X-Internal-Api-Key: $INTERNAL_API_KEY")
fi

curl -sS \
  "${HEADERS[@]}" \
  -d "$(jq -n --arg prompt "$PROMPT" --arg model "$MODEL" '{prompt: $prompt, model: $model}')" \
  "$URL/generate" | jq .
