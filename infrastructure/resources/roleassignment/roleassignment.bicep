@description('User assigned identity id')
param userAssignedIdentityId string

@description('Role definition id')
param roleDefinitionId string

@description('User assigned identity principal id')
param userAssignedPrincipalId string

resource RoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(userAssignedIdentityId, roleDefinitionId)
  scope: kubeletIdentity
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: userAssignedPrincipalId
    principalType: 'ServicePrincipal'
  }
}
