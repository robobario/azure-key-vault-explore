// Bicep template to deploy a Key Vault with an RSA key and an access policy
// for a specific application identity (Service Principal).

// PARAMETERS
// The unique name for your Key Vault. Must be globally unique.
param keyVaultName string = 'kv-${uniqueString(resourceGroup().id)}'

// The name for the RSA key inside the vault.
param keyName string = 'my-app-wrapping-key'

// The location for the resources, defaults to the resource group's location.
param location string = resourceGroup().location

// The unique Object ID of the app's Service Principal from Entra ID.
// This will be provided by the deployment script.
@description('The Object ID of the Microsoft Entra application (Service Principal) that needs access.')
param appObjectId string


// VARIABLES
// The tenant ID where the Key Vault and the app identity exist.
var tenantId = subscription().tenantId


// RESOURCES
// 1. The Azure Key Vault resource.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: false // Using legacy access policies as requested.
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: appObjectId // Granting access to your application.
        permissions: {
          keys: [
            'get' // 'get' is often needed to retrieve key properties before use.
            'wrapKey'
            'unwrapKey'
          ]
        }
      }
    ]
  }
}

// 2. The RSA Key resource, configured for wrap/unwrap operations.
resource rsaKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: keyName
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'wrapKey'
      'unwrapKey'
    ]
  }
}


// OUTPUTS
// Useful information about the deployed resources.
output keyVaultUri string = keyVault.properties.vaultUri
output keyId string = rsaKey.id
