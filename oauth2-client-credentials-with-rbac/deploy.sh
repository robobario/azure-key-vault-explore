#!/bin/bash

RESOURCE_GROUP="my-keyvault-rg3"
LOCATION="eastus"
APP_IDENTITY_NAME="my-secure-webapp-$(openssl rand -hex 4)"

echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

echo "Step 1: Creating Microsoft Entra application identity (Service Principal)..."
APP_CREDENTIALS=$(az ad sp create-for-rbac --name $APP_IDENTITY_NAME)

if [ -z "$APP_CREDENTIALS" ]; then
  echo "❌ Error: Failed to create the service principal."
  exit 1
fi

echo "------------------------------------------------------------------"
echo "✅ App Credentials Created. Store these securely."
echo "------------------------------------------------------------------"
echo $APP_CREDENTIALS
echo "------------------------------------------------------------------"

APP_ID=$(echo $APP_CREDENTIALS | jq -r '.appId')

echo "Step 2: Fetching the Service Principal's Object ID using its appId ($APP_ID)..."
APP_OBJECT_ID=$(az ad sp show --id $APP_ID | jq -r '.id')

if [ -z "$APP_OBJECT_ID" ] || [ "$APP_OBJECT_ID" == "null" ]; then
  echo "❌ Error: Failed to extract the Object ID using the appId."
  exit 1
fi

echo "✅ Object ID successfully fetched: $APP_OBJECT_ID"

echo "\nDeploying Bicep template..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters appObjectId=$APP_OBJECT_ID

echo "\n✨ Deployment complete."
