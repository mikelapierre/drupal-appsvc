param location string
param storageAccountName string
param vnetId string
param privateEndpointSubnetId string

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    publicNetworkAccess: 'Disabled'
  }    
    
  resource fileService 'fileServices' = {
    name: 'default'

    resource dbcert 'shares' = {
      name: 'dbcert'
    }

    resource drupal 'shares' = {
      name: 'drupal'
    }
  }
}

resource privatedns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
  resource vnetLink 'virtualNetworkLinks' = {
    name: 'storage-file-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetId
      }
      registrationEnabled: false
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${storageAccountName}-file-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'file'
        properties: {
          groupIds: [
            'file'
          ]
          privateLinkServiceId: storage.id
        }
      }
    ]
  }
  
  resource privatednsGroup 'privateDnsZoneGroups' = {
    name: 'file'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'file'
          properties: {
            privateDnsZoneId: privatedns.id
          }
        }
      ]
    }
  }
}
