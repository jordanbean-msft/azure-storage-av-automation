param logAnalyticsWorkspaceName string
param uploadBlobsStorageAccountName string
param storagePotentiallyUnsafeContainerName string
param storageSafeContainerName string
param location string
param newBlobCreatedEventGridTopicName string
param functionAppStorageAccountName string
param vNetName string
param functionAppSubnetName string
param uploadBlobStorageAccountSubnetName string

resource functionSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: '${vNetName}/${functionAppSubnetName}'
}

resource uploadBlobStorageAccountSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: '${vNetName}/${uploadBlobStorageAccountSubnetName}'
}

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: functionAppStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    // networkAcls: {
    //   defaultAction: 'Allow'
    //   bypass: 'AzureServices'
    //   virtualNetworkRules: [
    //     {
    //       id: functionSubnet.id
    //     }
    //   ]
    // }
  }
}

resource uploadBlobsStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: uploadBlobsStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    // networkAcls: {
    //   defaultAction: 'Allow'
    //   bypass: 'AzureServices'
    //   virtualNetworkRules: [
    //     {
    //       id: uploadBlobStorageAccountSubnet.id
    //     }
    //   ]
    // }
  }
}

resource potentiallyUnsafeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${uploadBlobsStorageAccount.name}/default/${storagePotentiallyUnsafeContainerName}'
}

resource safeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${uploadBlobsStorageAccount.name}/default/${storageSafeContainerName}'
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource functionStorageDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: functionAppStorageAccount
  properties: {
    workspaceId: logAnalytics.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource storageDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: uploadBlobsStorageAccount
  properties: {
    workspaceId: logAnalytics.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource storageBlobDiagnosticSettings 'Microsoft.Storage/storageAccounts/blobServices/providers/diagnosticsettings@2017-05-01-preview' = {
  name: '${uploadBlobsStorageAccount.name}/default/Microsoft.Insights/Logging'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource storageTableDiagnosticSettings 'Microsoft.Storage/storageAccounts/tableServices/providers/diagnosticsettings@2017-05-01-preview' = {
  name: '${uploadBlobsStorageAccount.name}/default/Microsoft.Insights/Logging'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource storageQueueDiagnosticSettings 'Microsoft.Storage/storageAccounts/queueServices/providers/diagnosticsettings@2017-05-01-preview' = {
  name: '${uploadBlobsStorageAccount.name}/default/Microsoft.Insights/Logging'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource blobCreatedEventGridTopic 'Microsoft.EventGrid/systemTopics@2021-06-01-preview' = {
  name: newBlobCreatedEventGridTopicName
  location: location
  properties: {
    source: uploadBlobsStorageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource blobCreatedEventGridTopicDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: blobCreatedEventGridTopic
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'DeliveryFailures'
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

resource eventGridConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'azureeventgrid'
  location: location
  properties: {
    api: {
      name: 'azureeventgrid'
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${uriComponent(location)}/managedApis/azureeventgrid'
      type: 'Microsoft.Web/locations/managedApis'
    }
    displayName: 'azureeventgrid'
  }
}

output uploadBlobsStorageAccountName string = uploadBlobsStorageAccount.name
output functionAppStorageAccountName string = functionAppStorageAccount.name
output newBlobCreatedEventGridTopicName string = blobCreatedEventGridTopic.name
output storagePotentiallyUnsafeContainerName string = storagePotentiallyUnsafeContainerName
output storageSafeContainerName string = storageSafeContainerName
