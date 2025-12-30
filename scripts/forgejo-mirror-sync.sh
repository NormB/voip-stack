#!/bin/bash
# Trigger Forgejo mirror sync
# Usage: ./forgejo-mirror-sync.sh <repo-name>

set -euo pipefail

REPO="${1:-opensips}"
FORGEJO_URL="${FORGEJO_URL:-http://localhost:3000}"
FORGEJO_USER="${FORGEJO_USER:-gator}"

# Try to get token from environment or Vault
if [[ -z "${FORGEJO_TOKEN:-}" ]] && [[ -f ~/.config/vault/root-token ]]; then
    FORGEJO_TOKEN=$(curl -s -H "X-Vault-Token: $(cat ~/.config/vault/root-token)" \
        "http://localhost:8200/v1/secret/data/forgejo/api-token" 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('data',{}).get('token',''))" 2>/dev/null || echo "")
fi

if [[ -z "${FORGEJO_TOKEN:-}" ]]; then
    echo "Error: FORGEJO_TOKEN not set and not found in Vault"
    echo "Set FORGEJO_TOKEN environment variable or store in Vault at secret/forgejo/api-token"
    exit 1
fi

echo "Syncing mirror: ${FORGEJO_USER}/${REPO}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${FORGEJO_URL}/api/v1/repos/${FORGEJO_USER}/${REPO}/mirror-sync" \
    -H "Authorization: token ${FORGEJO_TOKEN}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Mirror sync triggered successfully"
else
    echo "Error: HTTP ${HTTP_CODE}"
    echo "$BODY"
    exit 1
fi
