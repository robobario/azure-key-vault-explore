#!/bin/bash

# This script deletes the resource group and the Entra ID Service Principal.

# --- Configuration ---
RESOURCE_GROUP="my-keyvault-rg"
# The appId (Client ID) of the service principal you want to delete.
APP_ID_TO_DELETE=$1

# --- Script ---
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
