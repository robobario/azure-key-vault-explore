TOKEN=$(curl -sS -X POST https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "client_id=${CLIENT_ID}" \
-d "client_secret=${CLIENT_PASSWORD}" \
-d "scope=https://vault.azure.net/.default" \
-d "grant_type=client_credentials" | jq -r '.access_token')

curl "${VAULT_BASE_URL}/keys/my-app-wrapping-key?api-version=7.4" \
  -H "Authorization: Bearer ${TOKEN}"
