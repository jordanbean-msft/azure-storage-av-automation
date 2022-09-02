param logAnalyticsWorkspaceName string
param storageAccountName string
param storagePotentiallyUnsafeContainerName string
param storageSafeContainerName string
param location string
param newBlobCreatedEventGridTopicName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource potentiallyUnsafeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${storageAccount.name}/default/${storagePotentiallyUnsafeContainerName}'
}

resource safeContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${storageAccount.name}/default/${storageSafeContainerName}'
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource storageDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: storageAccount
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
  name: '${storageAccount.name}/default/Microsoft.Insights/Logging'
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
  name: '${storageAccount.name}/default/Microsoft.Insights/Logging'
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
  name: '${storageAccount.name}/default/Microsoft.Insights/Logging'
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
    source: storageAccount.id
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

output storageAccountName string = storageAccount.name
output newBlobCreatedEventGridTopicName string = blobCreatedEventGridTopic.name
output storagePotentiallyUnsafeContainerName string = storagePotentiallyUnsafeContainerName
output storageSafeContainerName string = storageSafeContainerName
