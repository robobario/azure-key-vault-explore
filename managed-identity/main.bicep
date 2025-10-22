// Bicep template that creates a Key Vault, a cheap Linux VM with a managed identity,
// and grants the VM's identity access to the Key Vault key using a custom role.

// PARAMETERS
@description('The unique name for your Key Vault. Must be globally unique.')
param keyVaultName string = 'kv-${uniqueString(resourceGroup().id)}'

@description('The name for the RSA key inside the vault.')
param keyName string = 'my-app-wrapping-key'

@description('The location for the resources, defaults to the resource group\'s location.')
param location string = resourceGroup().location

@description('The administrator username for the VM.')
param adminUsername string

@description('The public SSH key for the administrator account.')
@secure()
param adminSshKeyPublicKey string


// VARIABLES
@description('A unique name for the custom role.')
var customRoleName = 'Custom Key Vault Key Wrapper'
var vmName = 'app-vm-${uniqueString(resourceGroup().id)}'
var vnetName = 'app-vnet'
var subnetName = 'default'
var publicIpName = '${vmName}-pip'
var nsgName = '${vmName}-nsg'
var nicName = '${vmName}-nic'


// MODULE: Create the custom role definition at the subscription scope.
module roleDefinitionModule 'customRole.bicep' = {
  name: 'customRoleDeployment'
  scope: subscription()
  params: {
    customRoleName: customRoleName
  }
}


// RESOURCES
// 1. Key Vault and Key
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

// 2. Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// 3. Public IP Address (for SSH)
resource publicIp 'Microsoft.Network/publicIpAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 4. Network Security Group (to allow SSH)
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet' 
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// 5. Network Interface (NIC)
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// 6. Virtual Machine (with System-Assigned Managed Identity)
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned' // This line creates the managed identity
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s' // A cheap, burstable VM size
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS' // Cheapest disk storage
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshKeyPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// 7. Role Assignment (assigns the custom role to the VM's identity)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // ✅ CORRECTED: The name is now generated using the VM's name, which is known
  // before the deployment starts. This resolves the BCP120 error.
  name: guid(keyVault.id, vm.name, customRoleName)
  scope: keyVault // Assign the role at the Key Vault scope
  properties: {
    roleDefinitionId: roleDefinitionModule.outputs.customRoleId
    principalId: vm.identity.principalId // The ID of the VM's managed identity
    principalType: 'ServicePrincipal' // Managed Identities are a special type of Service Principal
  }
}


// OUTPUTS
output keyVaultUri string = keyVault.properties.vaultUri
output keyId string = rsaKey.id
output vmPublicIpAddress string = publicIp.properties.ipAddress
output vmAdminUsername string = adminUsername
