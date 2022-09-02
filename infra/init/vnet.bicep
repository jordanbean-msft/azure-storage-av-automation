param vNetName string
param addressPrefix string
param virusScannerSubnetName string
param virusScannerSubnetAddressPrefix string
param functionAppSubnetName string
param functionAppSubnetAddressPrefix string
param uploadBlobStorageAccountSubnetName string
param uploadBlobStorageAccountAddressPrefix string
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
      {
        name: 'Function-VM-Communication-Rule-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Function-VM-Communication-Rule-Outbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
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
      {
        name: functionAppSubnetName
        properties: {
          addressPrefix: functionAppSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgVirusScanner.id
          }
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: uploadBlobStorageAccountSubnetName
        properties: {
          addressPrefix: uploadBlobStorageAccountAddressPrefix
          networkSecurityGroup: {
            id: nsgVirusScanner.id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
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
output virusScannerSubnetName string = virusScannerSubnetName
output functionAppSubnetName string = functionAppSubnetName
output uploadBlobStorageAccountSubnetName string = uploadBlobStorageAccountSubnetName
