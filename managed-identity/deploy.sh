#!/bin/bash

# Configuration
RESOURCE_GROUP="my-keyvault-vm-rg"
LOCATION="eastus"
VM_ADMIN_USERNAME="azureuser"
SSH_KEY_NAME="azure_vm_key"

echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

# --- SSH Key Generation ---
# Check if SSH key already exists, if not, create one.
if [ ! -f ~/.ssh/$SSH_KEY_NAME ]; then
  echo "🔑 Generating SSH key pair '~/.ssh/$SSH_KEY_NAME'..."
  # Create a key with no passphrase for easy scripting
  ssh-keygen -t rsa -b 2048 -f ~/.ssh/$SSH_KEY_NAME -N ""
  echo "✅ SSH key pair generated."
else
  echo "ℹ️ Using existing SSH key pair '~/.ssh/$SSH_KEY_NAME'."
fi

# Read the public key content
SSH_PUBLIC_KEY=$(cat ~/.ssh/$SSH_KEY_NAME.pub)

echo "\n🚀 Deploying Bicep template (this may take a few minutes)..."
# Deploy and capture the JSON output from the Bicep template
DEPLOYMENT_OUTPUTS=$(az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters adminUsername=$VM_ADMIN_USERNAME \
               adminSshKeyPublicKey="$SSH_PUBLIC_KEY" \
  --query "properties.outputs" -o json)

if [ -z "$DEPLOYMENT_OUTPUTS" ]; then
  echo "❌ Error: Deployment failed or produced no output."
  exit 1
fi

echo "\n✨ Deployment complete."

# Extract outputs to construct the SSH command
VM_IP=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.vmPublicIpAddress.value')
VM_USER=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.vmAdminUsername.value')

# --- Final Instructions ---
echo "------------------------------------------------------------------"
echo "✅ VM Created. To connect, use the following command:"
echo ""
echo "ssh ${VM_USER}@${VM_IP} -i ~/.ssh/${SSH_KEY_NAME}"
echo ""
echo "------------------------------------------------------------------"
