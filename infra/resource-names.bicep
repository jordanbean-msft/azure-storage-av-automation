param appName string
param region string
param env string

output appInsightsName string = 'ai-${appName}-${region}-${env}'
output logAnalyticsWorkspaceName string = 'la-${appName}-${region}-${env}'
output storageAccountName string = toLower('sa${appName}${region}${env}')
output functionAppServicePlanName string = 'asp-func-${appName}-${region}-${env}'
output webAppServicePlanName string = 'asp-web-${appName}-${region}-${env}'
output functionUploadSafeFileAppName string = 'func-uploadSafeFile-${appName}-${region}-${env}'
output eventHubNamespaceName string = 'eh-${appName}-${region}-${env}'
output eventHubName string = 'uploaded-files'
output managedIdentityName string = 'mi-${appName}-${region}-${env}'
output newBlobCreatedEventGridTopicName string = 'egt-NewPotentiallyUnsafeBlobCreated-${appName}-${region}-${env}'
output functionScanBlobAppName string = 'func-scanBlob-${appName}-${region}-${env}'
output storagePotentiallyUnsafeContainerName string = 'potentially-unsafe'
output storageSafeContainerName string = 'safe'
output frontDoorName string = 'fd-${appName}-${region}-${env}'
output vmVirusScannerVMScaleSetName string = 'vmss-virusScanner-${appName}-${region}-${env}'
output vNetName string = 'vnet-${appName}-${region}-${env}'
output virusScannerSubnetName string = 'virus-scanner'
output nsgVirusScannerName string = 'nsg-virus-scanner'
