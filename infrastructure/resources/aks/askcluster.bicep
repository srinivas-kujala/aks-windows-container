param location string = resourceGroup().location

@description('Admin user account for the Domain Controller.')
param username string = 'azureuser'

@description('Admin user account for the Domain Controller.')
@secure()
param password string

@description('Existing vnet name')
param vNetName string

@description('VNet resource group name')
param vNetResourceGroupName string

@description('Node count. Default is 1')
param nodeCount int = 1

@description('Node vm size. Default vm size is Standard_Ds3_v2')
param nodeVmSize string = 'Standard_Ds3_v2'

@description('Kubernetes version. Default is 1.28.5')
param kubernetesVersion string = '1.28.5'

@description('Naming convention')
param namingConvention string

@description('gMSA DNS service ip address')
param gmsaDnsServerIp string

@description('Control plane user assigned identity id')
param controlPlaneIdentityId string

@description('Kubelet user assigned identity object')
param kubeletIdentity object

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-11-02-preview' = {
  name: '${namingConvention}-cluster'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${controlPlaneIdentityId}': {}
    }
  }
  properties: {
    dnsPrefix: '${namingConvention}-dns'
    kubernetesVersion: kubernetesVersion
    agentPoolProfiles: [
      {
        name: 'linux01'
        osDiskSizeGB: 0
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        mode: 'System'
        maxPods: 30
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, 'snet-02')
      }
      {
        name: 'win01'
        osDiskSizeGB: 0
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Windows'
        mode: 'User'
        maxPods: 30
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, 'snet-02')
      }
    ]
    identityProfile: {
      kubeletidentity: {
        resourceId: kubeletIdentity.id
        clientId: kubeletIdentity.clientId
        objectId: kubeletIdentity.principalId
      }
    }
    networkProfile: {
      dnsServiceIP: '10.0.3.4'
      networkPlugin: 'azure'
      serviceCidr: '10.0.3.0/24'
    }
    windowsProfile: {
      adminUsername: username
      adminPassword: password
      gmsaProfile: {
        enabled: true
      }
    }
  }
}
