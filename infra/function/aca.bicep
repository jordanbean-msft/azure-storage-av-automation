param containerRegistryName string
param containerAppManagedEnvironmentName string
param containerAppName string
param storageAccountName string
param logAnalyticsWorkspaceName string
param appInsightsName string
param managedIdentityName string
param location string
param computeImageName string
param computeImageTag string
param computeMinReplicas int
param computeMaxReplicas int
param storageQueueName string
param storageInputBlobContainerName string
param storageOutputBlobContainerName string
param computeLoopSleepTimeInSeconds string
param computeCpuResource int
param computeMemoryResource string
param daprComponentStorageInputQueueBindingName string
param daprComponentStorageInputContainerBindingName string
param daprComponentStorageOutputContainerBindingName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: containerRegistryName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: appInsightsName
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: containerAppManagedEnvironmentName
  location: location
  properties: {
    daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-06-01').primarySharedKey
      }
    }
  }

  resource daprComponentStorageInputQueueBinding 'daprComponents@2022-03-01' = {
    name: daprComponentStorageInputQueueBindingName
    properties: {
      componentType: 'bindings.azure.storagequeues'
      version: 'v1'
      secrets: [
        {
          name: 'storage-access-key'
          value: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
        }
      ]
      metadata: [
        {
          name: 'storageAccount'
          value: storageAccount.name
        }
        {
          name: 'storageAccessKey'
          secretRef: 'storage-access-key'
        }
        {
          name: 'queue'
          value: storageQueueName
        }
      ]
      scopes: [
        containerAppName
      ]
    }
  }
  resource daprComponentStorageInputContainerBinding 'daprComponents@2022-03-01' = {
    name: daprComponentStorageInputContainerBindingName
    properties: {
      componentType: 'bindings.azure.blobstorage'
      version: 'v1'
      secrets: [
        {
          name: 'storage-access-key'
          value: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
        }
      ]
      metadata: [
        {
          name: 'storageAccount'
          value: storageAccount.name
        }
        {
          name: 'storageAccessKey'
          secretRef: 'storage-access-key'
        }
        {
          name: 'container'
          value: storageInputBlobContainerName
        }
      ]
      scopes: [
        containerAppName
      ]
    }
  }
  resource daprComponentStorageOutputContainerBinding 'daprComponents@2022-03-01' = {
    name: daprComponentStorageOutputContainerBindingName
    properties: {
      componentType: 'bindings.azure.blobstorage'
      version: 'v1'
      secrets: [
        {
          name: 'storage-access-key'
          value: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
        }
      ]
      metadata: [
        {
          name: 'storageAccount'
          value: storageAccount.name
        }
        {
          name: 'storageAccessKey'
          secretRef: 'storage-access-key'
        }
        {
          name: 'container'
          value: storageOutputBlobContainerName
        }
      ]
      scopes: [
        containerAppName
      ]
    }
  }
}

var azureStorageConnectionStringSecretName = 'azure-storage-connection-string'

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: azureStorageConnectionStringSecretName
          value: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
        }
      ]
      dapr: {
        appId: containerAppName
        appPort: 1024
        appProtocol: 'grpc'
        enabled: true
      }
    }
    template: {
      containers: [
        {
          name: 'compute'
          image: '${containerRegistry.properties.loginServer}/${computeImageName}:${computeImageTag}'
          resources: {
            cpu: computeCpuResource
            memory: computeMemoryResource
          }
          probes: [
            {
              type: 'Liveness'
              periodSeconds: 3
              initialDelaySeconds: 7
              httpGet: {
                port: 1024
                path: '/health'
              }
            }
            {
              type: 'Readiness'
              tcpSocket: {
                port: 1024
              }
              initialDelaySeconds: 10
              periodSeconds: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: computeMinReplicas
        maxReplicas: computeMaxReplicas
        rules: [
          {
            name: 'storage-queue'
            custom: {
              type: 'queue-trigger'
              metadata: {
                accountName: storageAccount.name
                cloud: 'AzurePublicCloud'
              }
              auth: [
                {
                  secretRef: azureStorageConnectionStringSecretName
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

output containerAppName string = containerApp.name
