param acrName string = 'cr${uniqueString(resourceGroup().id)}'

param kvName string = 'kv-${uniqueString(resourceGroup().id)}'

param location string = resourceGroup().location
param resourceGroupName string = resourceGroup().name
param tenantId string = subscription().tenantId

@description('Admin user account for the Domain Controller.')
param username string = 'azureuser'

@description('Admin user account for the Domain Controller.')
@secure()
param password string

@description('Object ID of the current user.')
param currentUserObjectId string

@description('Existing vnet name')
param existingVNetName string

@description('VNet resource group name')
param vNetResourceGroupName string

@description('Node count. Default is 1')
param nodeCount int = 1

@description('Node vm size. Default vm size is Standard_Ds3_v2')
param nodeVmSize string = 'Standard_B2s'

@description('Kubernetes version. Default is 1.28.5')
param kubernetesVersion string = '1.28.5'

@description('Naming convention')
param namingConvention string

@description('gMSA DNS service ip address')
param gmsaDnsServerIp string

@description('List is subnet names')
param subNetNames array

var domainName = 'mydomain.local'

var dnsServerId = '10.0.1.4'
var azureDnsServer = '168.63.129.16'
var dnsServers = [ azureDnsServer, dnsServerId ]

// contributor id b24988ac-6180-42a0-ab88-20f7382dd24c
// "roleName": "Contributor",
// "description": "Grants full access to manage all resources, but does not allow you to assign roles in Azure RBAC, manage assignments in Azure Blueprints, or share image galleries."
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

// networkcontributor id 4d97b98b-1d4f-4787-a291-c67834d212e7
// "roleName": "Managed Identity Operator",
// "description": "Read and Assign User Assigned Identity"
var manageIdentityOperatorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'f1a07417-d97a-45cb-824c-7a7467783830')

// networkcontributor id 4d97b98b-1d4f-4787-a291-c67834d212e7
// "roleName": "Managed Identity Contributor",
// "description": "Create, Read, Update, and Delete User Assigned Identity"
var manageIdentityContributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59')

module virualMachines './resources/virtualmachine/virtialmachien.bicep' = {
  name: '${namingConvention}VMDeploy'
  params: {
    namingConvention: namingConvention
    location: location
  }
}

module controlPlaneIdentityModule './resources/identity/userassigned.bicep' ={
  name: '${namingConvention}-control-plane'
  params: {
    identityName: '${namingConvention}-control-plane'
    location: location
  }
}

module kubeletIdentityModule './resources/identity/userassigned.bicep' = {
  name: '${namingConvention}-kubelet'
  params: {
    identityName: '${namingConvention}-kubelet'
    location: location
  }
}

module kvModule './resources/keyvault/keyvault.bicep' = {
  name: 'keyvaultDeploy'
  params: {
    location: location
    tenantId: tenantId
    currentUserObjectId: currentUserObjectId
    namingConvention: namingConvention
    kubeletIdentity: kubeletIdentityModule.outputs.userAssignedIdentity
  }
}

module acrModule './resources/containerregistry/acr.bicep' = {
  name: 'acrDeploy'
  params: {
    location: location
    namingConvention: namingConvention
    currentUserObjectId: currentUserObjectId 
    kubeletIdentity: kubeletIdentityModule.outputs.userAssignedIdentity
  }
}

resource vnetNetworkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(controlPlaneIdentity.id, vnet01.id, networkContributorRoleDefinitionId)
  scope: vnet01
  properties: {
    roleDefinitionId: networkContributorRoleDefinitionId
    principalId: controlPlaneIdentityModule.outputs.userAssignedIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

module controlPlaneIdentityOperatorRoleAssignmentModule './resources/roleassignment/roleassignment.bicep' = {
  name: 'controlPlaneIdentityOperatorRoleAssignmentDeploy'
  params: {
    userAssignedIdentityId: controlPlaneIdentityModule.outputs.userAssignedIdentity.id  
    roleDefinitionId: manageIdentityOperatorRoleDefinitionId  
    userAssignedPrincipalId: controlPlaneIdentityModule.outputs.userAssignedIdentity.principalId
  }
}

module controlPlaneIdentityContributorRoleAssignmentModule './resources/roleassignment/roleassignment.bicep' = {
  name: 'controlPlaneIdentityContributorRoleAssignmentDeploy'
  params: {
    userAssignedIdentityId: controlPlaneIdentityModule.outputs.userAssignedIdentity.id  
    roleDefinitionId: manageIdentityContributorRoleDefinitionId  
    userAssignedPrincipalId: controlPlaneIdentityModule.outputs.userAssignedIdentity.principalId
  }
}

module askClusterModule './resources/aks/askcluster.bicep' = {
  name: 'askClusterDeploy'
  params: {
    location: location
    username: username
    password: password
    existingVNetName: existingVNetName
    vNetResourceGroupName: vNetResourceGroupName
    nodeCount: nodeCount
    nodeVmSize: nodeVmSize
    kubernetesVersion: kubernetesVersion
    namingConvention: namingConvention
    gmsaDnsServerIp: gmsaDnsServerIp
    subNetNames: subNetNames
    controlPlaneIdentityId: controlPlaneIdentityModule.outputs.userAssignedIdentity.id
    kubeletIdentity: kubeletIdentityModule.outputs.userAssignedIdentity
  }
}
