#!/bin/bash

# A script to create an Entra ID Service Principal and deploy the Key Vault using Bicep.

# --- Configuration ---
RESOURCE_GROUP="my-keyvault-rg"
LOCATION="eastus"
APP_IDENTITY_NAME="my-secure-webapp-$(openssl rand -hex 4)"

# --- Script ---
echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

echo "Step 1: Creating Microsoft Entra application identity (Service Principal)..."
APP_CREDENTIALS=$(az ad sp create-for-rbac --name $APP_IDENTITY_NAME)

# Check if credential creation was successful
if [ -z "$APP_CREDENTIALS" ]; then
  echo "❌ Error: Failed to create the service principal."
  exit 1
fi

echo "------------------------------------------------------------------"
echo "✅ App Credentials Created. Store these securely."
echo "------------------------------------------------------------------"
echo $APP_CREDENTIALS
echo "------------------------------------------------------------------"

# --- FIX IS HERE ---
# Step 2: Use the appId from the credentials to look up the full service principal
# and get its object ID.

# Extract the appId from the credentials JSON
APP_ID=$(echo $APP_CREDENTIALS | jq -r '.appId')

echo "Step 2: Fetching the Service Principal's Object ID using its appId ($APP_ID)..."
# The output of 'az ad sp show' contains the 'id' field, which is the objectId.
APP_OBJECT_ID=$(az ad sp show --id $APP_ID | jq -r '.id')
# --- END FIX ---

# Check if the Object ID was extracted successfully
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
