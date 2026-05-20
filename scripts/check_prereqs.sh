#!/usr/bin/env bash
set -euo pipefail

missing=0

for bin in gcloud terraform jq curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing: $bin"
    missing=1
  fi
done

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  echo "missing: active gcloud account. Run: gcloud auth login"
  missing=1
fi

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "missing: application default credentials. Run: gcloud auth application-default login"
  missing=1
fi

if ! gcloud billing accounts list --filter='open=true' --format='value(name)' | grep -q .; then
  echo "warning: no open billing account was found by gcloud"
fi

exit "$missing"
