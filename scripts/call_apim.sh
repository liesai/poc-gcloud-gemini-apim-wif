#!/usr/bin/env bash
set -euo pipefail

PROMPT="${1:-Reponds en francais en une phrase: que valide cette POC via APIM ?}"
URL="$(terraform -chdir=terraform-azure-apim output -raw gemini_generate_url)"

curl -sS \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg prompt "$PROMPT" '{prompt: $prompt}')" \
  "$URL" | jq .
