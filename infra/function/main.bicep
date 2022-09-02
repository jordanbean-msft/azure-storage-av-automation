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

module functionDeployment 'func.bicep' = {
  name: 'functionDeployment'
  params: {
    appServicePlanName: names.outputs.appServicePlanName
    location: location
    managedIdentityName: names.outputs.managedIdentityName
    orchestrationFunctionAppName: names.outputs.orchestrationFunctionAppName
    storageAccountInputContainerName: names.outputs.storageAccountInputContainerName
    logAnalyticsWorkspaceName: names.outputs.logAnalyticsWorkspaceName
    appInsightsName: names.outputs.appInsightsName
    storageAccountQueueName: names.outputs.storageInputQueueName
    storageAccountName: names.outputs.storageAccountName
  }
}

module eventSubscriptionDeployment 'eventSubscription.bicep' = {
  name: 'eventSubscriptionDeployment'
  params: {
    orchtestrationFunctionAppName: functionDeployment.outputs.orchestrationFunctionAppName
    storageAccountOutputContainerName: names.outputs.storageAccountOutputContainerName
    newBlobCreatedEventGridTopicName: names.outputs.newBlobCreatedEventGridTopicName
  }
}

module acaDeployment 'aca.bicep' = {
  name: 'acaDeployment'
  params: {
    containerRegistryName: names.outputs.containerRegistryName
    logAnalyticsWorkspaceName: names.outputs.logAnalyticsWorkspaceName
    containerAppName: names.outputs.containerAppName
    appInsightsName: names.outputs.appInsightsName
    location: location
    storageAccountName: names.outputs.storageAccountName
    managedIdentityName: names.outputs.managedIdentityName
    computeImageName: computeImageName
    computeImageTag: computeImageTag
    computeMinReplicas: computeMinReplicas
    computeMaxReplicas: computeMaxReplicas
    storageQueueName: names.outputs.storageInputQueueName
    storageInputBlobContainerName: names.outputs.storageAccountInputContainerName
    storageOutputBlobContainerName: names.outputs.storageAccountOutputContainerName
    computeLoopSleepTimeInSeconds: computeLoopSleepTimeInSeconds
    computeCpuResource: computeCpuResource
    computeMemoryResource: computeMemoryResource
    containerAppManagedEnvironmentName: names.outputs.containerAppManagedEnvironmentName
    daprComponentStorageInputQueueBindingName: names.outputs.daprComponentStorageInputQueueBindingName
    daprComponentStorageInputContainerBindingName: names.outputs.daprComponentStorageInputContainerBindingName
    daprComponentStorageOutputContainerBindingName: names.outputs.daprComponentStorageOutputContainerBindingName
  }
}

output containerAppName string = acaDeployment.outputs.containerAppName
