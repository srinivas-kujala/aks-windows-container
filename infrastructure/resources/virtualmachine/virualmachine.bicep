param location string = resourceGroup().location

@description('Naming convention')
param namingConvention string

@description('DNS Server ID')
param dnsServerId string

@description('DNS servers')
param dnsServers string

@description('Virtual machine size')
param vmSize string

@description('Admin user account for the DC.')
param username string = 'useradmin'

@description('Admin user account for the DC.')
@secure()
param password string

@description('ControlPlabe user assigned identity object')
param controlPlaneIdentity object

// networkcontributor id 4d97b98b-1d4f-4787-a291-c67834d212e7
// "roleName": "Network Contributor",
// "description": "Lets you manage networks, but not access to them."
var networkContributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

resource vnet01 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: '${namingConvention}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'snet-01'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'snet-02'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

resource dcNetworkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${namingConvention}-nic-dc'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: vnet01.properties.subnets[1].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          privateIPAddress: dnsServerId
        }
      }
    ]
  }
}

resource vm01NetworkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${namingConvention}-nic-vm'
  location: location
  properties: {
    dnsSettings: {
      dnsServers: [
        dnsServerId
      ]
    }
    ipConfigurations: [
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.5'
          subnet: {
            id: vnet01.properties.subnets[1].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

resource dc 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: '${namingConvention}-vm-dc'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${namingConvention}-vm-dc'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${namingConvention}-disk-dc'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dcNetworkInterface.id
        }
      ]
    }
  }
}

resource vm01 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: '${namingConvention}-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${namingConvention}-vm'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-22h2-ent'
        version: 'latest'
      }
      osDisk: {
        name: '${namingConvention}-disk-vm'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm01NetworkInterface.id
        }
      ]
    }
  }
}

resource dcScript 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'dc-script'
  location: location
  parent: dc
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      commandToExecute: 'powershell Install-WindowsFeature AD-Domain-Services -IncludeManagementTools; Install-ADDSForest -DomainName "mycompany.local" -DomainNetbiosName mycompany -InstallDNS -SafeModeAdministratorPassword $(ConvertTo-SecureString "${password}" -AsPlainText -Force) -Force'
    }
  }
}

resource basIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: '${namingConvention}-ip-bas'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: '${namingConvention}-bas'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${namingConvention}-ip-bas'
        properties: {
          subnet: {
            id: vnet01.properties.subnets[0].id
          }
          publicIPAddress: {
            id: basIp.id
          }
        }
      }
    ]
  }
}

resource vnetNetworkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(controlPlaneIdentity.id, vnet01.id, networkContributorRoleDefinitionId)
  scope: vnet01
  properties: {
    roleDefinitionId: networkContributorRoleDefinitionId
    principalId: controlPlaneIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}
