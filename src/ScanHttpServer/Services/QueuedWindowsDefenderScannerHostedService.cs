namespace ScanHttpServer.Services
{
  public class QueuedWindowsDefenderScannerHostedService : BackgroundService
  {
    private readonly ILogger<QueuedWindowsDefenderScannerHostedService> _logger;

    public QueuedWindowsDefenderScannerHostedService(IBackgroundTaskQueue taskQueue,
        ILogger<QueuedWindowsDefenderScannerHostedService> logger)
    {
      TaskQueue = taskQueue;
      _logger = logger;
    }

    public IBackgroundTaskQueue TaskQueue { get; }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
      _logger.LogInformation($"Queued Hosted Service is running.{Environment.NewLine}");

      await BackgroundProcessing(stoppingToken);
    }

    private async Task BackgroundProcessing(CancellationToken stoppingToken)
    {
      while (!stoppingToken.IsCancellationRequested)
      {
        var workItem =
            await TaskQueue.DequeueAsync(stoppingToken);

        try
        {
          await workItem(stoppingToken);
        }
        catch (Exception ex)
        {
          _logger.LogError(ex,
              "Error occurred executing {WorkItem}.", nameof(workItem));
        }
      }
    }

    public override async Task StopAsync(CancellationToken stoppingToken)
    {
      _logger.LogInformation("Queued Hosted Service is stopping.");

      await base.StopAsync(stoppingToken);
    }
  }
}