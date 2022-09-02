param vNetName string
param addressPrefix string
param virusScannerSubnetName string
param virusScannerSubnetAddressPrefix string
param location string
param nsgVirusScannerName string
param logAnalyticsWorkspaceName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource nsgVirusScanner 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: nsgVirusScannerName
  location: location
  properties: {
    securityRules: [

    ]
  }
}

resource vNet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: virusScannerSubnetName
        properties: {
          addressPrefix: virusScannerSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgVirusScanner.id
          }
        }
      }
    ]
  }
}

resource vNetDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: vNet
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      // {
      //   category: 'VMProtectionAlert'
      //   enabled: true
      // }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource nsgVirusScannerDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: nsgVirusScanner
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

output vNetName string = vNet.name
output virusScannerSubnetName string = vNet.properties.subnets[0].name
