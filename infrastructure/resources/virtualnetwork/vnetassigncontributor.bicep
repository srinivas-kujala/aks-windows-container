@description('Existing vnet name')
param existingVNetName string

@description('VNet resource group name')
param vNetResourceGroupName string

@description('Kubelet user assigned identity object')
param kubeletIdentity object

// networkcontributor id 4d97b98b-1d4f-4787-a291-c67834d212e7
// "roleName": "Network Contributor",
// "description": "Lets you manage networks, but not access to them."
var networkContributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

// TODO:need to associate subnets with route table.
resource existingVNet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: existingVNetName
  scope: resourceGroup(vNetResourceGroupName)
}

// Assigning existing vnet role assignment
resource vnetNetworkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(kubeletIdentity.id, existingVNet.id, networkContributorRoleDefinitionId)
  scope: existingVNet
  properties: {
    roleDefinitionId: networkContributorRoleDefinitionId
    principalId: kubeletIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}
