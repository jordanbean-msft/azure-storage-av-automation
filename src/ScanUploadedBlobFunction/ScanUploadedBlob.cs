using Microsoft.Extensions.Logging;
using System;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.Identity;
using Azure.Storage.Blobs.Models;
using System.Text;
using System.Text.Json;

namespace ScanUploadedBlobFunction
{
  public class ScanUploadedBlob
  {
    private readonly ILogger _logger;

    public ScanUploadedBlob(ILoggerFactory loggerFactory)
    {
      _logger = loggerFactory.CreateLogger<ScanUploadedBlob>();
    }

    [Function("ScanUploadedBlob")]
    public async Task Run([EventGridTrigger] BlobCreatedEvent input)
    {
      var blobName = input.Data.Url.Split("/").Last();
      var blobSize = input.Data.ContentLength.ToString();
      var blobUrl = input.Data.Url;

      _logger.LogInformation($"Processing blob - Name:{blobName} Size: {blobSize} Bytes");

      var scannerHost = Environment.GetEnvironmentVariable("WINDOWS_DEFNDER_HOST");
      var scannerPort = Environment.GetEnvironmentVariable("WINDOWS_DEFENDER_PORT");

      var scanner = new ScannerProxy(_logger, scannerHost);

      BlobClient downloadBlobClient = new BlobClient(new Uri(blobUrl),
                                                     new DefaultAzureCredential(new DefaultAzureCredentialOptions
                                                     {
                                                       ManagedIdentityClientId = Environment.GetEnvironmentVariable("ManagedIdentityClientId")
                                                     }));

      var blobStream = await downloadBlobClient.OpenReadAsync();

      var scanResults = scanner.Scan(blobStream, blobName);

      if (scanResults == null)
      {
        return;
      }

      _logger.LogInformation($"Scan Results - {scanResults.ToString(", ")}");
      _logger.LogInformation("Handalng Scan Results");

      var action = new Remediation(scanResults, _logger);

      action.Start();

      _logger.LogInformation($"ScanUploadedBlob function done Processing blob Name:{blobName} Size: {blobSize} Bytes");
    }
  }
}
