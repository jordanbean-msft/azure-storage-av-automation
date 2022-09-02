using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Logging;
using System;
using System.Threading.Tasks;

namespace ScanUploadedBlobFunction
{
  public class Remediation
  {
    private ScanResults scanResults { get; }
    private ILogger log { get; }
    public Remediation(ScanResults scanResults, ILogger log)
    {
      this.scanResults = scanResults;
      this.log = log;
    }

    public void Start()
    {
      string potentiallyUnsafeContainerName = Environment.GetEnvironmentVariable("AZURE_STORAGE_POTENTIALLY_UNSAFE_CONTAINER_NAME");

      if (scanResults.isThreat)
      {
        log.LogInformation($"A malicious file was detected, file name: {scanResults.fileName}, threat type: {scanResults.threatType}");
      }

      else
      {
        try
        {
          string safeContainerName = Environment.GetEnvironmentVariable("AZURE_STORAGE_SAFE_CONTAINER_NAME");
          MoveBlob(scanResults.fileName, potentiallyUnsafeContainerName, safeContainerName, log).GetAwaiter().GetResult();
          log.LogInformation("The file is clean. It has been moved from the unscanned container to the clean container");
        }

        catch (Exception e)
        {
          log.LogError($"The file is clean, but moving it to the clean storage container failed. {e.Message}");
        }
      }
    }

    private static async Task MoveBlob(string srcBlobName, string srcContainerName, string destContainerName, ILogger log)
    {
      var uploadBlobsStorageAccountName = Environment.GetEnvironmentVariable("AZURE_UPLOAD_BLOBS_STORAGE_ACCOUNT_NAME");

      var srcContainer = new BlobContainerClient(new Uri($"https://{uploadBlobsStorageAccountName}.blob.core.windows.net/{srcContainerName}"),
        new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
          ManagedIdentityClientId = Environment.GetEnvironmentVariable("ManagedIdentityClientId")
        })
      );

      var destContainer = new BlobContainerClient(new Uri($"https://{uploadBlobsStorageAccountName}.blob.core.windows.net/{destContainerName}"),
        new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
          ManagedIdentityClientId = Environment.GetEnvironmentVariable("ManagedIdentityClientId")
        })
      );

      var srcBlob = srcContainer.GetBlobClient(srcBlobName);
      var destBlob = destContainer.GetBlobClient(srcBlobName);

      if (await srcBlob.ExistsAsync())
      {
        log.LogInformation("MoveBlob: Started file copy");
        await destBlob.StartCopyFromUriAsync(srcBlob.Uri);

        log.LogInformation("MoveBlob: Done file copy");
        await srcBlob.DeleteAsync();

        log.LogInformation("MoveBlob: Source file deleted");
      }
    }
  }
}
