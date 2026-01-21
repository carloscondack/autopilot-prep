<#
.SYNOPSIS
    Bootstrap script for Intune Autopilot Enrollment via PowerShell 7.
    Designed to be curled and run from a fresh OOBE environment.
#>

$ErrorActionPreference = "Stop"

# --- 1. TLS Setup (Crucial for GitHub/PSGallery connectivity) ---
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# --- 2. Check/Install PowerShell 7 ---
$PwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"

if (-not (Test-Path $PwshPath)) {
    Write-Host "[-] PowerShell 7 not found. Fetching latest MSI..." -ForegroundColor Cyan
    
    try {
        $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $MsiAsset = $LatestRelease.assets | Where-Object { $_.name -like "*-win-x64.msi" } | Select-Object -First 1
        
        if (-not $MsiAsset) { throw "Could not find MSI asset." }

        $TempMsi = "$env:TEMP\$($MsiAsset.name)"
        Write-Host "[-] Downloading $($MsiAsset.name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $MsiAsset.browser_download_url -OutFile $TempMsi

        Write-Host "[-] Installing PowerShell 7..." -ForegroundColor Cyan
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$TempMsi`" /quiet /norestart" -Wait
    }
    catch {
        Write-Error "Critical Failure installing PowerShell 7: $_"
        exit 1
    }
}

# --- 3. Create the Payload Script for PS7 ---
# We write the actual Intune logic to a temp file to execute it cleanly inside PS7
$PayloadFile = "$env:TEMP\IntuneEnrollment.ps1"

$PayloadContent = @"
Write-Host "[-] Configuring PowerShell 7 Environment..." -ForegroundColor Green
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

# Check/Install NuGet (Required for Install-Script)
if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
    Write-Host "[-] Installing NuGet Provider..." -ForegroundColor Green
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# Check/Install Autopilot Script
if (-not (Get-InstalledScript -Name Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue)) {
    Write-Host "[-] Installing Get-WindowsAutopilotInfo..." -ForegroundColor Green
    Install-Script -Name Get-WindowsAutopilotInfo -Force | Out-Null
}

Write-Host "[-] Starting Authentication (Phishing Resistant)..." -ForegroundColor Yellow
Write-Host "    A browser window will open shortly." -ForegroundColor Gray

# Run the command
Get-WindowsAutopilotInfo -Online
"@

Set-Content -Path $PayloadFile -Value $PayloadContent

# --- 4. Hand off to PowerShell 7 ---
Write-Host "[-] Launching Modern Auth Flow..." -ForegroundColor Cyan
& "C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File $PayloadFile

Write-Host "[-] Done." -ForegroundColor Cyan