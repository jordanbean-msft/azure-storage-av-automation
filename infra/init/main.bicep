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
param vmssVirusScannerInstanceCount int

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
    storageAccountName: names.outputs.storageAccountName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
    storagePotentiallyUnsafeContainerName: names.outputs.storagePotentiallyUnsafeContainerName
    storageSafeContainerName: names.outputs.storageSafeContainerName
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
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultDeployment.outputs.keyVaultName
}

module vmssDeployment 'vmss.bicep' = {
  name: 'vmssDeployment'
  params: {
    loadBalancerName: names.outputs.loadBalancerName
    location: location
    virusScannerSubnetName: vNetDeployment.outputs.virusScannerSubnetName
    vmAdminPasswordSecret: keyVault.getSecret(names.outputs.vmAdminPasswordSecretName)
    vmAdminUsernameSecret: keyVault.getSecret(names.outputs.vmAdminUsernameSecretName)
    vmssVirusScannerInstanceCount: vmssVirusScannerInstanceCount
    vmssVirusScannerName: names.outputs.vmVirusScannerVMScaleSetName
    vNetName: vNetDeployment.outputs.vNetName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
  }
}
