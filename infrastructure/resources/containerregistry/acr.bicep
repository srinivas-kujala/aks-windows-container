param location string = resourceGroup().location

@description('Naming convention')
param namingConvention string

@description('Object ID of the current user.')
param currentUserObjectId string

@description('Kubelet user assigned identity object')
param kubeletIdentity object

// contributor id b24988ac-6180-42a0-ab88-20f7382dd24c
// "roleName": "Contributor",
// "description": "Grants full access to manage all resources, but does not allow you to assign roles in Azure RBAC, manage assignments in Azure Blueprints, or share image galleries."
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

// acr pull role id 7f951dda-4ed3-4680-a7ca-43fe172d538d
// "roleName": "AcrPull",
// "description": "acr pull"
var acrPullRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: '${namingConvention}-acr'
  location: location
  sku: {
    name: 'Basic'
  }
}

resource acrRoleAssignmentForUser 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(currentUserObjectId, contributorRoleDefinitionId)
  scope: acr
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

resource acrRoleAssignmentForKubelet 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(kubeletIdentity.id, acrPullRoleDefinitionId)
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: kubeletIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}
