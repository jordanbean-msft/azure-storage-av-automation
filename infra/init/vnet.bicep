param vNetName string
param addressPrefix string
param virusScannerSubnetName string
param virusScannerSubnetAddressPrefix string
param location string
param nsgVirusScannerName string

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

output vNetName string = vNet.name
output virusScannerSubnetName string = vNet.properties.subnets[0].name
