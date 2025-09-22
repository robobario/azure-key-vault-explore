#!/bin/bash

RESOURCE_GROUP="my-keyvault-rg3"
APP_ID_TO_DELETE=$1

if [ -z "$APP_ID_TO_DELETE" ]; then
  echo "❌ Error: Please provide the appId of the Service Principal as the first argument."
  echo "Usage: ./teardown.sh <your-app-id>"
  exit 1
fi

echo "Deleting resource group '$RESOURCE_GROUP'..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "Deleting Entra ID Service Principal with appId '$APP_ID_TO_DELETE'..."
az ad sp delete --id $APP_ID_TO_DELETE

echo "\n✨ Teardown initiated."
