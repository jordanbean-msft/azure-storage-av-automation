param appName string
param environment string
param region string
param location string = resourceGroup().location
param computeImageName string
param computeImageTag string
param computeMinReplicas int
param computeMaxReplicas int
param computeLoopSleepTimeInSeconds string
param computeCpuResource int
param computeMemoryResource string

module names '../resource-names.bicep' = {
  name: 'namesDeployment'
  params: {
    appName: appName
    env: environment
    region: region
  }
}

module managedIdentityDeployment 'managed-identity.bicep' = {
  name: 'managedIdentityDeployment'
  params: {
    managedIdentityName: names.outputs.managedIdentityName
    location: location
  }
}

module loggingDeployment 'logging.bicep' = {
  name: 'loggingDeployment'
  params: {
    appInsightsName: names.outputs.appInsightsName
    location: location
    logAnalyticsWorkspaceName: names.outputs.logAnalyticsWorkspaceName
    orchestrationFunctionAppName: names.outputs.orchestrationFunctionAppName
  }
}

module storageDeployment 'storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    newBlobCreatedEventGridTopicName: names.outputs.newBlobCreatedEventGridTopicName
    storageAccountName: names.outputs.storageAccountName
    storageInputBlobContainerName: names.outputs.storageAccountInputContainerName
    storageOutputBlobContainerName: names.outputs.storageAccountOutputContainerName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    storageInputQueueName: names.outputs.storageInputQueueName
  }
}

module containerRegistryDeployment 'acr.bicep' = {
  name: 'containerRegistryDeployment'
  params: {
    containerRegistryName: names.outputs.containerRegistryName
    location: location
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    managedIdentityName: managedIdentityDeployment.outputs.managedIdentityName
  }
}

output storageAccountName string = storageDeployment.outputs.storageAccountName
output storageAccountInputContainerName string = storageDeployment.outputs.inputContainerName
output storageAccountInputQueueName string = storageDeployment.outputs.inputQueueName
output storageAccountOutputContainerName string = storageDeployment.outputs.outputContainerName
output containerRegistryName string = containerRegistryDeployment.outputs.containerRegistryName
output logAnalyticsWorkspaceName string = loggingDeployment.outputs.logAnalyticsWorkspaceName
output appInsightsName string = loggingDeployment.outputs.appInsightsName
