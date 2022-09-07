using System.Net;
using Microsoft.AspNetCore.Mvc;
using ScanHttpServer.Services;
using ScanHttpServer.Utilities;
using Microsoft.Net.Http.Headers;
using Microsoft.AspNetCore.WebUtilities;

namespace ScanHttpServer.Controllers
{
  [ApiController]
  public class HomeController : ControllerBase
  {
    private ILogger logger;
    private readonly IBackgroundTaskQueue taskQueue;

    private IConfiguration configuration;
    private readonly string[] permittedExtensions;
    private readonly long fileSizeLimit;

    public HomeController(ILogger logger, IBackgroundTaskQueue taskQueue, IConfiguration configuration)
    {
      this.logger = logger;
      this.taskQueue = taskQueue;
      this.configuration = configuration;

      permittedExtensions = configuration.GetValue<string[]>("PermittedExtensions");
      fileSizeLimit = configuration.GetValue<long>("FileSizeLimit");
    }

    [HttpPost("scan")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UploadPhysical()
    {
      if (!MultipartRequestHelper.IsMultipartContentType(Request.ContentType))
      {
        ModelState.AddModelError("File",
            $"The request couldn't be processed (Error 1).");

        return BadRequest(ModelState);
      }

      var boundary = MultipartRequestHelper.GetBoundary(
          MediaTypeHeaderValue.Parse(Request.ContentType),
          configuration.GetValue<int>("MultipartBoundaryLengthLimit"));
      var reader = new MultipartReader(boundary, HttpContext.Request.Body);
      var section = await reader.ReadNextSectionAsync();
      string targetFilePath = Path.GetTempFileName();
      string trustedFileNameForDisplay;

      while (section != null)
      {
        var hasContentDispositionHeader =
            ContentDispositionHeaderValue.TryParse(
                section.ContentDisposition, out var contentDisposition);

        if (hasContentDispositionHeader)
        {
          // This check assumes that there's a file
          // present without form data. If form data
          // is present, this method immediately fails
          // and returns the model error.
          if (!MultipartRequestHelper
              .HasFileContentDisposition(contentDisposition))
          {
            ModelState.AddModelError("File",
                $"The request couldn't be processed (Error 2).");

            return BadRequest(ModelState);
          }
          else
          {
            // Don't trust the file name sent by the client. To display
            // the file name, HTML-encode the value.
            trustedFileNameForDisplay = WebUtility.HtmlEncode(
                    contentDisposition.FileName.Value);

            var streamedFileContent = await FileHelpers.ProcessStreamedFile(
                section, contentDisposition, ModelState,
                permittedExtensions, fileSizeLimit);

            if (!ModelState.IsValid)
            {
              return BadRequest(ModelState);
            }


            using (var targetStream = System.IO.File.Create(
                Path.Combine(targetFilePath)))
            {
              await targetStream.WriteAsync(streamedFileContent);

              logger.LogInformation($"Uploaded file '{trustedFileNameForDisplay}' saved to '{targetFilePath}'");
            }
          }
        }

        // Drain any remaining section body that hasn't been consumed and
        // read the headers for the next section.
        section = await reader.ReadNextSectionAsync();
      }

      var windowsDefenderScannerService = new WindowsDefenderScannerService(logger, targetFilePath);
      await taskQueue.QueueBackgroundWorkItemAsync((cancellationToken) => { return windowsDefenderScannerService.Scan(cancellationToken); });
      var result = windowsDefenderScannerService.ScanResults;

      if (result.isError)
      {
        logger.LogError("Error during the scanning Error message:{errorMessage}", result.errorMessage);

        var data = new
        {
          ErrorMessage = result.errorMessage,
        };

        return StatusCode((int)HttpStatusCode.InternalServerError, data);
      }

      var responseData = new
      {
        FileName = result.fileName,
        isThreat = result.isThreat,
        ThreatType = result.threatType
      };

      try
      {
        System.IO.File.Delete(targetFilePath);
      }
      catch (Exception e)
      {
        logger.LogError(e, $"Exception caught when trying to delete temp file:{targetFilePath}.");
      }

      return Ok(responseData);
    }
  }
}