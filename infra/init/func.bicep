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

resource appServicePlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: functionAppServicePlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'EP1'
  }
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

resource functionScanBlobAppFunction 'Microsoft.Web/sites@2021-01-15' = {
  name: functionScanBlobAppName
  location: location
  kind: 'functionapp,linux'
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', functionAppStorageAccount.name), '2019-06-01').keys[0].value}'
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT_NAME'
          value: functionAppStorageAccount.name
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
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
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
