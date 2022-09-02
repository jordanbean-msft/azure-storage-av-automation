param vNetName string
param virusScannerSubnetName string
param location string
param loadBalancerName string
param logAnalyticsWorkspaceName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource virusScannerSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${vNetName}/${virusScannerSubnetName}'
}

var loadBalancerFrontEndIpConfigurationName = 'LoadBalancerFrontEndIpConfiguration'
var loadBalancerBackEndAddressPoolName = 'LoadBalancerBackEndAddressPool'
var loadBalancerProbeName = 'LoadBalancerProbe'

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: loadBalancerFrontEndIpConfigurationName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virusScannerSubnet.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: loadBalancerBackEndAddressPoolName
      }
    ]
    probes: [
      {
        name: loadBalancerProbeName
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 4
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'virusScannerLoadBalancingRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.network/loadBalancers/frontendIpConfigurations', loadBalancerName, loadBalancerFrontEndIpConfigurationName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndAddressPoolName)
          }
          probe: {
            id: resourceId('Microsoft.network/loadBalancers/probes', loadBalancerName, loadBalancerProbeName)
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
    ]
  }
}

resource loadBalancerDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Logging'
  scope: loadBalancer
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output loadBalancerName string = loadBalancer.name
