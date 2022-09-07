$ErrorActionPreference = "Stop"

$ScanHttpServerRootDirectory = "C:\ScanHttpServer"
$ScanHttpServerBinDirectory = "$ScanHttpServerRootDirectory\bin"

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

Write-Information "Registering Windows Service to run ScanHttpServer..."

$scanHttpServerService = New-Service -Name ScanHttpServer `
  -BinaryPathName "$ScanHttpServerBinDirectory\ScanHttpServer.exe" `
  -DisplayName "ScanHttpServer" `
  -StartupType Automatic

Write-Information "Registered Windows Service to run ScanHttpServer"

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

New-NetFirewallRule -DisplayName "ScanHttpServerComunicationIn" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "ScanHttpServerComunicationOut" -Direction Outbound -LocalPort 443 -Protocol TCP -Action Allow

Write-Information "Added Firewall Rules"

# Write-Information "Downloading .NET 6 runtime..."
# if (-Not (Test-Path $ScanHttpServerFolder\dotnet-install.ps1)) {
#   Invoke-WebRequest "https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1" -OutFile $ScanHttpServerBinDirectory\dotnet-install.ps1
# }

# Write-Information "Downloaded .NET 6 runtime..."

# Write-Host "Installing .NET 6 Runtime..."

# .\dotnet-install.ps1 -Channel 6.0 -Runtime dotnet

# Write-Host "Installed .NET 6 Runtime..."

Write-Information "Updating Signatures for Windows Defender..."

& "C:\Program Files\Windows Defender\MpCmdRun.exe" -SignatureUpdate

Write-Information "Updated Signatures for Windows Defender"

Write-Information "Setting ASPNETCORE_URLS environment variable..."

[System.Environment]::SetEnvironmentVariable('ASPNETCORE_URLS', 'https://localhost:443', 'Machine')

Write-Information "Set ASPNETCORE_URLS environment variable"

Write-Information "Starting Windows Service to run ScanHttpServer..."

Start-Service -Name ScanHttpServer

Write-Information "Started Windows Service to run ScanHttpServer"

Stop-Transcript