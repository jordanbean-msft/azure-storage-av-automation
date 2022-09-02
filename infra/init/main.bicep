param appName string
param environment string
param region string
param location string = resourceGroup().location
@secure()
param vmAdminUsername string
@secure()
param vmAdminPassword string
param addressPrefix string
param virusScannerSubnetAddressPrefix string
param functionAppSubnetAddressPrefix string
param uploadBlobStorageAccountSubnetAddressPrefix string
param vmssVirusScannerInstanceCount int
param vmInitializationScriptName string
param virusScanHttpServerPackageName string

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
    functionUploadSafeFileAppName: names.outputs.functionUploadSafeFileAppName
  }
}

module storageDeployment 'storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    newBlobCreatedEventGridTopicName: names.outputs.newBlobCreatedEventGridTopicName
    functionAppSubnetName: vNetDeployment.outputs.functionAppSubnetName
    uploadBlobsStorageAccountName: names.outputs.uploadBlobStorageAccountName
    functionAppStorageAccountName: names.outputs.functionAppStorageAccountName
    vNetName: vNetDeployment.outputs.vNetName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    storagePotentiallyUnsafeContainerName: names.outputs.storagePotentiallyUnsafeContainerName
    storageSafeContainerName: names.outputs.storageSafeContainerName
    uploadBlobStorageAccountSubnetName: vNetDeployment.outputs.uploadBlobStorageAccountSubnetName
    buildArtifactContainerName: names.outputs.buildArtifactContainerName
    managedIdentityName: managedIdentityDeployment.outputs.managedIdentityName
  }
}

module keyVaultDeployment 'keyVault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: names.outputs.keyVaultName
    location: location
    vmAdminPassword: vmAdminPassword
    vmAdminPasswordSecretName: names.outputs.vmAdminPasswordSecretName
    vmAdminUsername: vmAdminUsername
    vmAdminUsernameSecretName: names.outputs.vmAdminUsernameSecretName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
  }
}

module vNetDeployment 'vnet.bicep' = {
  name: 'vNetDeployment'
  params: {
    addressPrefix: addressPrefix
    location: location
    nsgVirusScannerName: names.outputs.nsgVirusScannerName
    virusScannerSubnetAddressPrefix: virusScannerSubnetAddressPrefix
    virusScannerSubnetName: names.outputs.virusScannerSubnetName
    vNetName: names.outputs.vNetName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    functionAppSubnetAddressPrefix: functionAppSubnetAddressPrefix
    functionAppSubnetName: names.outputs.functionAppSubnetName
    uploadBlobStorageAccountAddressPrefix: uploadBlobStorageAccountSubnetAddressPrefix
    uploadBlobStorageAccountSubnetName: names.outputs.uploadBlobStorageAccountSubnetName
  }
}

module loadBalancerDeployment 'load-balancer.bicep' = {
  name: 'loadBalancerDeployment'
  params: {
    loadBalancerName: names.outputs.loadBalancerName
    location: location
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    virusScannerSubnetName: vNetDeployment.outputs.virusScannerSubnetName
    vNetName: vNetDeployment.outputs.vNetName
  }
}

module functionDeployment 'func.bicep' = {
  name: 'functionDeployment'
  params: {
    appInsightsName: loggingDeployment.outputs.appInsightsName
    functionAppServicePlanName: names.outputs.functionAppServicePlanName
    functionScanBlobAppName: names.outputs.functionScanBlobAppName
    location: location
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    managedIdentityName: managedIdentityDeployment.outputs.managedIdentityName
    functionAppStorageAccountName: storageDeployment.outputs.functionAppStorageAccountName
    storagePotentiallyUnsafeContainerName: storageDeployment.outputs.storagePotentiallyUnsafeContainerName
    functionAppSubnetName: vNetDeployment.outputs.functionAppSubnetName
    vNetName: vNetDeployment.outputs.vNetName
    loadBalancerName: loadBalancerDeployment.outputs.loadBalancerName
    storageSafeContainerName: storageDeployment.outputs.storageSafeContainerName
    uploadBlobsStorageAccountName: storageDeployment.outputs.uploadBlobsStorageAccountName
  }
}
