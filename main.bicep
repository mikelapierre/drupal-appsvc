param location string = resourceGroup().location
param storageAccountName string = 'stg${uniqueString(resourceGroup().name)}'
param appSvcName string = 'appsvc-${uniqueString(resourceGroup().name)}'
param databaseServerName string = 'dbsrv-${uniqueString(resourceGroup().name)}'
param databaseName string = 'drupal'
param databaseAdminUser string
@secure()
param databaseAdminPassword string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet'
  location: location
  properties: {
    addressSpace: {
       addressPrefixes: [
        '10.10.0.0/21'
       ]
    }
    subnets: [
      {
        name: 'app-service'
        properties: {
          addressPrefix: '10.10.0.0/24'
          delegations: [
            {
              name: 'Microsoft.Web/serverfarms'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: '10.10.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]    
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageAccountName: storageAccountName
  }  
}

module securestorage 'secure-storage.bicep' = {
  name: 'secure-storage'
  params: {
    location: location
    storageAccountName: storageAccountName
    vnetId: vnet.id
    privateEndpointSubnetId: vnet.properties.subnets[1].id
  }
  dependsOn: [
    storage
  ]
}

module appservice 'appservice.bicep' = {
  name: 'appservice'
  params: {
    location: location
    storageAccountName: storageAccountName
    appSvcName: appSvcName
    databaseServerName: databaseServerName
    databaseName: databaseName
    databaseAdminUser: databaseAdminUser
    databaseAdminPassword: databaseAdminPassword
    appServiceSubnetId: vnet.properties.subnets[0].id
  }  
  dependsOn: [
    securestorage
  ]
}

module registry 'database.bicep' = {
  name: 'database'
  params: {
    location: location
    databaseServerName: databaseServerName
    databaseName: databaseName
    databaseAdminUser: databaseAdminUser
    databaseAdminPassword: databaseAdminPassword
    vnetId: vnet.id
    privateEndpointSubnetId: vnet.properties.subnets[1].id    
  }
}
