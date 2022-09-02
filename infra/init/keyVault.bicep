param keyVaultName string
param location string
param vmAdminUsernameSecretName string
param vmAdminPasswordSecretName string
@secure()
param vmAdminUsername string
@secure()
param vmAdminPassword string
param logAnalyticsWorkspaceName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

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
    accessPolicies: [
    ]
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

resource keyVaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    // logs: [
    //   {
    //     category: 'AuditLogs'
    //     enabled: true
    //   }
    //   {
    //     category: 'AzurePolicyEvaluationDetails'
    //     enabled: true
    //   }
    // ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output keyVaultName string = keyVault.name
output vmAdminUsernameSecretName string = vmAdminUsernameSecretName
output vmAdminPasswordSecretName string = vmAdminPasswordSecretName
