param newBlobCreatedEventGridTopicName string
param functionScanBlobAppName string
param storagePotentiallyUnsafeContainerName string

resource functionScanBlobApp 'Microsoft.Web/sites@2021-01-15' existing = {
  name: functionScanBlobAppName
}

resource newBlobCreatedEventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-06-01-preview' = {
  name: '${newBlobCreatedEventGridTopicName}/newBlobCreatedForRaiseEventFunctionAppEventSubscription'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionScanBlobApp.id}/functions/ScanUploadedBlob'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${storagePotentiallyUnsafeContainerName}'
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}
