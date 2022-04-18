param location string
param databaseServerName string
param databaseName string
param databaseAdminUser string
@secure()
param databaseAdminPassword string
param vnetId string
param privateEndpointSubnetId string

resource databaseServer 'Microsoft.DBforMariaDB/servers@2018-06-01' = {
  name: databaseServerName
  location: location
  sku: {
    name: 'GP_Gen5_2'
  }  
  properties:  {
    administratorLogin: databaseAdminUser
    administratorLoginPassword: databaseAdminPassword
    createMode: 'Default'
    version: '10.3'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLS1_2'    
    publicNetworkAccess: 'Disabled'
  }

  resource database 'databases' = {
    name: databaseName
  }
}

resource privatedns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.mariadb.database.azure.com'
  location: 'global'
  resource vnetLink 'virtualNetworkLinks' = {
    name: 'mariadb-link'
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
  name: '${databaseServerName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'mariadbServer'
        properties: {
          groupIds: [
            'mariadbServer'
          ]
          privateLinkServiceId: databaseServer.id
        }
      }
    ]
  }
  
  resource privatednsGroup 'privateDnsZoneGroups' = {
    name: 'mariadbServer'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'mariadbServer'
          properties: {
            privateDnsZoneId: privatedns.id
          }
        }
      ]
    }
  }
}
