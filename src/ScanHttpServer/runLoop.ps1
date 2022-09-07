$ScanHttpServerFolder = "C:\ScanHttpServer\bin"
$ExePath = "$ScanHttpServerFolder\ScanHttpServer.dll"

Set-Location $ScanHttpServerFolder
Start-Transcript -Path runLoopStartup.log

Write-Information "Downloading .NET 6 runtime..."
if (-Not (Test-Path $ScanHttpServerFolder\dotnet-install.ps1)) {
  Invoke-WebRequest "https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1" -OutFile $ScanHttpServerBinDirectory\dotnet-install.ps1
}

Write-Information "Installing .NET 6 Runtime..."

.\dotnet-install.ps1 -Channel 6.0 -Runtime dotnet

Write-Information "Starting Process $ExePath"
while ($true) {
  $process = Start-Process dotnet -ArgumentList $ExePath -PassThru -Wait
    
  if ($process.ExitCode -ne 0) {
    Write-Information "Process Exited with errors, please check the logs in $ScanHttpServerFolder\log"
  }
  else {
    Write-Information "Proccess Exited with no errors"
  }

  Write-Information "Restarting Process $ExePath"
}
Stop-Transcript