param location string
param databaseServerName string
param databaseName string
param databaseAdminUser string
@secure()
param databaseAdminPassword string
param authorizedIps string

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
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLS1_2'
    version: '10.3'    
  }

  resource firewwllRule 'firewallRules' = [for (ip,i) in split(authorizedIps, ','): {
    name: 'allowAppSvc-${i}'
    properties: {
      endIpAddress: ip
      startIpAddress: ip
    }    
  }]

  resource database 'databases' = {
    name: databaseName
  }
}
