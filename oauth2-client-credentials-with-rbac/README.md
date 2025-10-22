## deploy

Deploy keyvault and set up service account, demonstrate obtaining a bearer token from Entra for access to Key Vault

`./deploy.sh`

Extract the details from the output of deploy,sh

TENANT_ID=${tenant here} CLIENT_PASSWORD=${password here} CLIENT_ID=${appId here} VAULT_BASE_URL=${vault uri from deploy output} ./client.sh

## tear down

`./teardown.sh {Entra appId}`
