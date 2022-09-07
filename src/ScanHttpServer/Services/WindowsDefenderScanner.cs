using System;
using System.Diagnostics;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using ScanHttpServer.Models;

namespace ScanHttpServer.Services
{
  internal interface IWindowsDefenderScannerService
  {
    ValueTask Scan(CancellationToken stoppingToken);
  }
  public class WindowsDefenderScannerService : IWindowsDefenderScannerService
  {
    private const string SCANNING_LINE_START = "Scanning";
    private const string THREAT_TYPE_LINE_START = "Threat";
    private const string ERROR_LINE_START = "CmdTool:";
    private const string OUTPUT_ERROR_LINE_START = "ERROR";
    private static readonly string INTERNAL_ERROR_MESSAGE = "Internal Server Error";
    private static readonly string WINDOWS_DEFENDER_CMD_RUN_PATH = @"C:\Program Files\Windows Defender\MpCmdRun.exe";

    private readonly string fullFilePath;

    public WindowsDefenderScannerService(ILogger logger, string fullFilePath)
    {
      this.logger = logger;
      this.fullFilePath = fullFilePath;
    }

    private ILogger logger { get; }

    public ScanResults ScanResults { get; private set; }

    public async ValueTask Scan(CancellationToken stoppingToken)
    {
      logger.LogInformation($"Start Scanning {fullFilePath}...");

      string prefixArgs = @" -Scan -ScanType 3 -File ";
      string suffixArgs = " -DisableRemediation";

      string scanProcessOutput = await RunScannerProcess(stoppingToken, prefixArgs + fullFilePath + suffixArgs);

      if (scanProcessOutput == null)
      {
        ScanResults = new ScanResults() { isError = true, errorMessage = INTERNAL_ERROR_MESSAGE };
      }

      logger.LogInformation($"Scanning output {scanProcessOutput}");

      ScanResults = ParseScanOutput(scanProcessOutput);
    }

    private async Task<string> RunScannerProcess(CancellationToken stoppingToken, string arguments)
    {
      logger.LogInformation($"command executed: \n{WINDOWS_DEFENDER_CMD_RUN_PATH + arguments}");

      var process = new Process();
      process.StartInfo.FileName = WINDOWS_DEFENDER_CMD_RUN_PATH;
      process.StartInfo.Arguments = arguments;
      process.StartInfo.UseShellExecute = false;
      process.StartInfo.RedirectStandardOutput = true;
      process.StartInfo.RedirectStandardError = true;

      try
      {
        process.Start();
        await process.WaitForExitAsync(stoppingToken);
        string proccesOutput = process.StandardOutput.ReadToEnd();
        return proccesOutput;
      }
      catch (Exception e)
      {
        logger.LogError(e, "Exception caught when trying to start the scanner process.");
        return null;
      }
    }

    private ScanResults ParseScanOutput(string scanProcessOutput)
    {
      logger.LogInformation("Parsing scan output");

      string resultString = Regex.Replace(scanProcessOutput, @"^\s*$\n|\r", string.Empty, RegexOptions.Multiline).TrimEnd();
      var linesArray = resultString.Split(new[] { '\r', '\n' });
      var result = new ScanResults() { isError = false };

      foreach (string line in linesArray)
      {
        ReadScanOutputLine(result, line);
      }

      if (result.isError)
      {
        result.errorMessage = scanProcessOutput;
      }
      logger.LogInformation("Done Parsing scan Output");
      return result;
    }

    private void ReadScanOutputLine(ScanResults result, string line)
    {
      var words = line.Split(' ');
      switch (words[0])
      {
        case SCANNING_LINE_START:
          if (words.Length < 2)
          {
            logger.LogError("Error trying to parse scan results, Scanning line contain only one word");
            result.isError = true;
            return;
          }

          if (int.TryParse(words[^2], out var numOfThreatsFound))
          {
            result.isThreat = true;
            break;
          }
          else
          {
            result.isThreat = false;
            return;
          }

        case THREAT_TYPE_LINE_START:
          result.threatType = String.Join(' ', words.Skip(1));
          return;

        case ERROR_LINE_START:
          result.isError = true;
          return;
      }
    }
  }
}
