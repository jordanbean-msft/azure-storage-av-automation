param appInsightsName string
param logAnalyticsWorkspaceName string
param functionScanBlobAppName string
param storagePotentiallyUnsafeContainerName string
param functionAppStorageAccountName string
param functionAppServicePlanName string
param location string
param managedIdentityName string
param vNetName string
param functionAppSubnetName string
param storageSafeContainerName string
param loadBalancerName string
param uploadBlobsStorageAccountName string

resource appServicePlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: functionAppServicePlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'EP1'
  }
}

resource uploadBlobsStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: uploadBlobsStorageAccountName
}

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: functionAppStorageAccountName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource functionAppSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${vNetName}/${functionAppSubnetName}'
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' existing = {
  name: loadBalancerName
}

var functionAppStorageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', functionAppStorageAccount.name), '2019-06-01').keys[0].value}'

resource functionScanBlobAppFunction 'Microsoft.Web/sites@2021-01-15' = {
  name: functionScanBlobAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      vnetRouteAllEnabled: true
      netFrameworkVersion: 'v6.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: functionAppStorageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: functionAppStorageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: uniqueString(functionScanBlobAppName)
        }
        {
          name: 'AZURE_UPLOAD_BLOBS_STORAGE_ACCOUNT_NAME'
          value: uploadBlobsStorageAccount.name
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AZURE_STORAGE_POTENTIALLY_UNSAFE_CONTAINER_NAME'
          value: storagePotentiallyUnsafeContainerName
        }
        {
          name: 'AZURE_STORAGE_SAFE_CONTAINER_NAME'
          value: storageSafeContainerName
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'WINDOWS_DEFENDER_HOST'
          value: loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
        }
        {
          name: 'WINDOWS_DEFENDER_PORT'
          value: '443'
        }
      ]
    }
  }
  resource functionScanBlobAppFunctionNetworkConfig 'networkConfig@2022-03-01' = {
    name: 'virtualNetwork'
    properties: {
      subnetResourceId: functionAppSubnet.id
      swiftSupported: true
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource functionAppDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: functionScanBlobAppFunction
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output functionScanBlobAppName string = functionScanBlobAppName
