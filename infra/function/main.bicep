param appName string
param environment string
param region string
param location string = resourceGroup().location
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

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: names.outputs.keyVaultName
}

module vmssDeployment 'vmss.bicep' = {
  name: 'vmssDeployment'
  params: {
    loadBalancerName: names.outputs.loadBalancerName
    location: location
    virusScannerSubnetName: names.outputs.virusScannerSubnetName
    vmAdminPasswordSecret: keyVault.getSecret(names.outputs.vmAdminPasswordSecretName)
    vmAdminUsernameSecret: keyVault.getSecret(names.outputs.vmAdminUsernameSecretName)
    vmssVirusScannerInstanceCount: vmssVirusScannerInstanceCount
    vmssVirusScannerName: names.outputs.vmVirusScannerVMScaleSetName
    vNetName: names.outputs.vNetName
    buildArtifactContainerName: names.outputs.buildArtifactContainerName
    vmInitializationScriptName: vmInitializationScriptName
    virusScanHttpServerPackageName: virusScanHttpServerPackageName
    functionAppStorageAccountName: names.outputs.functionAppStorageAccountName
    managedIdentityName: names.outputs.managedIdentityName
  }
}

module eventSubscriptionDeployment 'eventSubscription.bicep' = {
  name: 'eventSubscriptionDeployment'
  params: {
    functionScanBlobAppName: names.outputs.functionScanBlobAppName
    newBlobCreatedEventGridTopicName: names.outputs.newBlobCreatedEventGridTopicName
    storagePotentiallyUnsafeContainerName: names.outputs.storagePotentiallyUnsafeContainerName
  }
}
