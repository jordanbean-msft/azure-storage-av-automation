$ErrorActionPreference = "Stop"

#Init
$ScanHttpServerRootDirectory = "C:\ScanHttpServer"
$ScanHttpServerBinDirectory = "$ScanHttpServerRootDirectory\bin"
$runLoopPath = "$ScanHttpServerBinDirectory\runLoop.ps1"

Start-Transcript -Path C:\VmInit.log

Write-Information "Creating $ScanHttpServerRootDirectory..."

New-Item -ItemType Directory $ScanHttpServerRootDirectory -Force

Write-Information "Created $ScanHttpServerRootDirectory"

Write-Information "Creating $ScanHttpServerBinDirectory..."

New-Item -ItemType Directory $ScanHttpServerBinDirectory -Force

Write-Information "Created $ScanHttpServerBinDirectory"

if ($args.Count -gt 0) {
  if (-Not (Test-Path $ScanHttpServerBinDirectory\vminit.config)) {
    Write-Information "Creating $ScanHttpServerBinDirectory\vminit.config. file..."

    New-Item $ScanHttpServerBinDirectory\vminit.config
    
    Write-Information "Created $ScanHttpServerBinDirectory\vminit.config. file"
  }
  Set-Content $ScanHttpServerBinDirectory\vminit.config $args[0]
}

$ScanHttpServerBinZipUrl = Get-Content $ScanHttpServerBinDirectory\vminit.config

Write-Information "Retrieving access token using Managed Identity to download $ScanHttpServerBinZipUrl..."

$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' `
  -Headers @{Metadata = "true" } `
  -UseBasicParsing

Write-Information "Retrieved access token using Managed Identity to download $ScanHttpServerBinZipUrl"

$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token

Write-Information "Downloading $ScanHttpServerBinZipUrl..."

Invoke-WebRequest $ScanHttpServerBinZipUrl `
  -Headers @{ Authorization = "Bearer $access_token"; "x-ms-version" = "2020-04-08" } `
  -OutFile $ScanHttpServerBinDirectory\ScanHttpServer.zip `
  -UseBasicParsing

Write-Information "Downloaded $ScanHttpServerBinZipUrl"

Expand-Archive $ScanHttpServerBinDirectory\ScanHttpServer.zip -DestinationPath $ScanHttpServerBinDirectory -Force

Set-Location $ScanHttpServerBinDirectory

Write-Information "Scheduling task for startup"

&schtasks /create /tn StartScanHttpServer /sc onstart /tr "powershell.exe C:\ScanHttpServer\bin\runLoop.ps1"  /NP /DELAY 0001:00 /RU SYSTEM

Write-Information "Creating and adding certificate..."

$cert = New-SelfSignedCertificate -DnsName ScanServerCert -CertStoreLocation "Cert:\LocalMachine\My"
$thumb = $cert.Thumbprint
$appGuid = '{' + [guid]::NewGuid().ToString() + '}'

Write-Information "Successfully created new certificate $cert"

Write-Information "Adding netsh Rules..."

netsh http delete sslcert ipport=0.0.0.0:443
netsh http add sslcert ipport=0.0.0.0:443 appid=$appGuid certhash="$thumb"

Write-Information "Added netsh Rules..."

Write-Information "Adding Firewall Rules..."

New-NetFirewallRule -DisplayName "ServerFunctionComunicationIn" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "ServerFunctionComunicationOut" -Direction Outbound -LocalPort 443 -Protocol TCP -Action Allow

Write-Information "Added Firewall Rules"

Write-Information "Updating Signatures for Windows Defender..."

& "C:\Program Files\Windows Defender\MpCmdRun.exe" -SignatureUpdate

Write-Information "Updated Signatures for Windows Defender"

Write-Information "Starting RunLoop..."

Start-Process powershell -Verb runas -ArgumentList $runLoopPath

Write-Information "Started RunLoop"

Stop-Transcript