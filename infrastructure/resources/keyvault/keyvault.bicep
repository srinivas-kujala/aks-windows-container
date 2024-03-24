param location string = resourceGroup().location
param tenantId string = subscription().tenantId

@description('Object ID of the current user.')
param currentUserObjectId string

@description('Naming convention')
param namingConvention string

@description('Kubelet user assigned identity object')
param kubeletIdentity object

// kv secret officer role id b86a8fe4-44ce-4948-aee5-eccb2c155cd7
// "roleName": "Key Vault Secrets Officer"
// "description": "Perform any action on the secrets of a key vault, except manage permissions. Only works for key vaults that use the 'Azure role-based access control' permission model."
var kvSecretOfficerRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')

// kv secret user role id 4633458b-17de-408a-b874-0445c86b69e6
// "roleName": "Key Vault Secrets User"
// "description": "Read secret contents. Only works for key vaults that use the 'Azure role-based access control' permission model."
var kvSecretUserRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: '${namingConvention}-kv'
  location: location
  properties: {
    tenantId: tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableSoftDelete: false
    enableRbacAuthorization: true
  }
}

resource kvRoleAssignmentForUser 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(currentUserObjectId, kvSecretOfficerRoleDefinitionId)
  scope: kv
  properties: {
    roleDefinitionId: kvSecretOfficerRoleDefinitionId
    principalId: currentUserObjectId
    principalType: 'User'
  }
}

resource kvRoleAssignmentForAks 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(kubeletIdentity.id, kvSecretUserRoleDefinitionId)
  scope: kv
  properties: {
    roleDefinitionId: kvSecretUserRoleDefinitionId
    principalId: kubeletIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

