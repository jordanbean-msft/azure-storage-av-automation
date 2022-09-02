param vmssVirusScannerName string
param vNetName string
param virusScannerSubnetName string
@secure()
param vmAdminUsernameSecret string
@secure()
param vmAdminPasswordSecret string
param vmssVirusScannerInstanceCount int
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

resource vmssVirusScanner 'Microsoft.Compute/virtualMachineScaleSets@2022-03-01' = {
  name: vmssVirusScannerName
  location: location
  sku: {
    name: 'Standard_D2s_v3'
    tier: 'Standard'
    capacity: vmssVirusScannerInstanceCount
  }
  properties: {
    overprovision: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      osProfile: {
        adminUsername: vmAdminUsernameSecret
        adminPassword: vmAdminPasswordSecret
        computerNamePrefix: 'virusscan'
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2022-Datacenter'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          diskSizeGB: 128
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'virus-scanner-nic'
            properties: {
              primary: true
              enableAcceleratedNetworking: true
              enableIPForwarding: true
              ipConfigurations: [
                {
                  name: 'virus-scanner-ip'
                  properties: {
                    subnet: {
                      id: virusScannerSubnet.id
                    }
                    primary: true
                    loadBalancerBackendAddressPools: [
                      {
                        id: loadBalancer.properties.backendAddressPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource autoscalehost 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = {
  name: 'autoscalehost'
  location: location
  properties: {
    name: 'autoscalehost'
    targetResourceUri: vmssVirusScanner.id
    enabled: true
    profiles: [
      {
        name: 'Profile1'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmssVirusScanner.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 50
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmssVirusScanner.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
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

output vmssVirusScannerName string = vmssVirusScanner.name
output loadBalancerName string = loadBalancer.name
