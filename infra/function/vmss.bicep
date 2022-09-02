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
param functionAppStorageAccountName string
param buildArtifactContainerName string
param vmInitializationScriptName string
param virusScanHttpServerPackageName string
param managedIdentityName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource virusScannerSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${vNetName}/${virusScannerSubnetName}'
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' existing = {
  name: loadBalancerName
}

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: functionAppStorageAccountName
}

resource buildArtifactContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' existing = {
  name: '${functionAppStorageAccountName}/default/${buildArtifactContainerName}'
}

var buildArtifactContainerUrlPrefix = 'https://${functionAppStorageAccount.name}.blob.core.windows.net/${buildArtifactContainer.name}'

resource vmssVirusScanner 'Microsoft.Compute/virtualMachineScaleSets@2022-03-01' = {
  name: vmssVirusScannerName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
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
      extensionProfile: {
        extensions: [
          {
            name: 'virus-scanner-extension'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.10'
              autoUpgradeMinorVersion: true
              protectedSettings: {
                fileUris: [
                  '${buildArtifactContainerUrlPrefix}/${vmInitializationScriptName}'
                ]
                commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File VMInit.ps1 "${buildArtifactContainerUrlPrefix}/${virusScanHttpServerPackageName}"'
                managedIdentity: {
                  clientId: managedIdentity.properties.clientId
                }
              }
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

output vmssVirusScannerName string = vmssVirusScanner.name
