@description('Resource location')
param location string = resourceGroup().location

@description('Identity name')
param identityName string

resource Identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: identityName
  location: location
}

output userAssignedIdentity object = {
  id: Identity.id
  clientId: Identity.properties.clientId
  principalId : Identity.properties.principalId
}
