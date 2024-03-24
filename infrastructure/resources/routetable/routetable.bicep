param location string = resourceGroup().location

@description('Naming convention')
param namingConvention string

resource routeTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: '${namingConvention}-rt'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}
