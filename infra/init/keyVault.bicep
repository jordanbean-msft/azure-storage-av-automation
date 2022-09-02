param keyVaultName string
param location string
param vmAdminUsernameSecretName string
param vmAdminPasswordSecretName string
@secure()
param vmAdminUsername string
@secure()
param vmAdminPassword string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForTemplateDeployment: true
  }
  resource vmAdminUsernameSecret 'secrets@2022-07-01' = {
    name: vmAdminUsernameSecretName
    properties: {
      value: vmAdminUsername
    }
  }
  resource vmAdminPasswordSecret 'secrets@2022-07-01' = {
    name: vmAdminPasswordSecretName
    properties: {
      value: vmAdminPassword
    }
  }
}

output keyVaultName string = keyVault.name
output vmAdminUsernameSecretName string = vmAdminUsernameSecretName
output vmAdminPasswordSecretName string = vmAdminPasswordSecretName
