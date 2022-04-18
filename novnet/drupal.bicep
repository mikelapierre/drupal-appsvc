param location string = resourceGroup().location
param storageAccountName string = 'stg${uniqueString(resourceGroup().name)}'
param appSvcName string = 'appsvc-${uniqueString(resourceGroup().name)}'
param databaseServerName string = 'dbsrv-${uniqueString(resourceGroup().name)}'
param databaseName string = 'drupal'
param databaseAdminUser string
@secure()
param databaseAdminPassword string

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  
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

resource uploadRootCert 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployscript-upload-file'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.30.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storage.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storage.listKeys().keys[0].value
      }
    ]
    scriptContent: 'curl -o dbcert.crt.pem https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem && az storage file upload --source dbcert.crt.pem -s dbcert'
  }
}

resource appSvcPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${appSvcName}-plan'
  location: location  
  sku: {
    name: 'P1v3'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource appSvc 'Microsoft.Web/sites@2021-03-01' = {
  name: '${appSvcName}-web'
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appSvcPlan.id
    siteConfig: {
       linuxFxVersion: 'DOCKER|bitnami/drupal-nginx:latest'
    }    
  }

  resource web 'config' = {
    name: 'web'
    properties: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://index.docker.io/v1'
        }
        {
          name: 'DRUPAL_DATABASE_HOST'
          value: '${databaseServerName}.mariadb.database.azure.com'
        }
        {
          name: 'DRUPAL_DATABASE_NAME'
          value: databaseName
        }
        {
          name: 'DRUPAL_DATABASE_PASSWORD'
          value: databaseAdminPassword
        }
        {
          name: 'DRUPAL_DATABASE_PORT_NUMBER'
          value: '3306'
        }
        {
          name: 'DRUPAL_DATABASE_USER'
          value: databaseAdminUser
        }
        {
          name: 'WEBSITES_CONTAINER_START_TIME_LIMIT'
          value: '1200'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'DRUPAL_DATABASE_TLS_CA_FILE'
          value: '/etc/dbcert/dbcert.crt.pem'
        }
        {
          name: 'MYSQL_CLIENT_ENABLE_SSL'
          value: 'yes'
        }
      ]
       azureStorageAccounts: {
        dbcert: {
          accessKey: storage.listKeys().keys[0].value
          accountName: storage.name
          mountPath: '/etc/dbcert'
          shareName: 'dbcert'
          type: 'AzureFiles'
        }       
        drupal: {
          accessKey: storage.listKeys().keys[0].value
          accountName: storage.name
          mountPath: '/bitnami/drupal'
          shareName: 'drupal'
          type: 'AzureFiles'
        }          
       }
       httpLoggingEnabled: true
    }
  }
  dependsOn: [
    uploadRootCert
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
    authorizedIps: appSvc.properties.possibleOutboundIpAddresses
  }
}
