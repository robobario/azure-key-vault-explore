// Bicep template that creates a custom RBAC role for specific Key Vault key actions
// and assigns it to a service principal.

// PARAMETERS
@description('The unique name for your Key Vault. Must be globally unique.')
param keyVaultName string = 'kv-${uniqueString(resourceGroup().id)}'

@description('The name for the RSA key inside the vault.')
param keyName string = 'my-app-wrapping-key'

@description('The location for the resources, defaults to the resource group\'s location.')
param location string = resourceGroup().location

@description('The Object ID of the Microsoft Entra application (Service Principal) that needs access.')
param appObjectId string


// VARIABLES
@description('A unique name for the custom role.')
var customRoleName = 'Custom Key Vault Key Wrapper'


// MODULE
// Deploy the custom role definition at the subscription scope.
module roleDefinitionModule 'customRole.bicep' = {
  name: 'customRoleDeployment' // A unique name for the deployment operation
  scope: subscription() // This tells Bicep to deploy the module to the subscription.
  params: {
    customRoleName: customRoleName
  }
}


// RESOURCES
// 1. The Azure Key Vault resource, deployed to the resource group.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
  }
}

// 2. The RSA Key resource.
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

// 3. The Role Assignment.
// This assigns the custom role (from the module) to the service principal.
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // CORRECTED: The name is now generated using the customRoleName variable,
  // which is known before the deployment starts.
  name: guid(keyVault.id, appObjectId, customRoleName)
  scope: keyVault
  properties: {
    // Get the role ID from the module's output. This is fine here.
    roleDefinitionId: roleDefinitionModule.outputs.customRoleId
    principalId: appObjectId
    principalType: 'ServicePrincipal'
  }
}


// OUTPUTS
output keyVaultUri string = keyVault.properties.vaultUri
output keyId string = rsaKey.id
output customRoleId string = roleDefinitionModule.outputs.customRoleId
