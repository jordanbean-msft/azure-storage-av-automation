using Microsoft.Extensions.Hosting.WindowsServices;
using ScanHttpServer.Services;

var options = new WebApplicationOptions
{
  Args = args,
  ContentRootPath = WindowsServiceHelpers.IsWindowsService()
                                     ? AppContext.BaseDirectory : default
};

var builder = WebApplication.CreateBuilder(options);
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHostedService<QueuedWindowsDefenderScannerHostedService>();
builder.Services.AddSingleton<IBackgroundTaskQueue>(ctx =>
{
  if (!int.TryParse(builder.Configuration["QueueCapacity"], out var queueCapacity))
    queueCapacity = 100;
  return new BackgroundTaskQueue(queueCapacity);
});

builder.Host.UseWindowsService();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
  app.UseSwagger();
  app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseRouting();
await app.RunAsync();
