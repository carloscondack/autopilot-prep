<#
.SYNOPSIS
    Bootstrap script for Intune Autopilot Enrollment via PowerShell 7.
    Version 2.0 - Fixes PATH issues on re-runs.
#>

$ErrorActionPreference = "Stop"

# --- 1. TLS Setup ---
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
$PayloadFile = "$env:TEMP\IntuneEnrollment.ps1"

# NOTE: The logic below now finds the specific path of the script to avoid PATH errors
$PayloadContent = @"
Write-Host "[-] Configuring PowerShell 7 Environment..." -ForegroundColor Green
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

# 1. NuGet Provider
if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
    Write-Host "[-] Installing NuGet Provider..." -ForegroundColor Green
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# 2. Autopilot Script (Install or Locate)
$ScriptName = "Get-WindowsAutopilotInfo"
$ScriptInfo = Get-InstalledScript -Name $ScriptName -ErrorAction SilentlyContinue

if (-not $ScriptInfo) {
    Write-Host "[-] Installing Get-WindowsAutopilotInfo..." -ForegroundColor Green
    Install-Script -Name $ScriptName -Force -Scope CurrentUser | Out-Null
    $ScriptInfo = Get-InstalledScript -Name $ScriptName
}

# 3. Execution (Using Full Path)
# We construct the full path to ensure it runs even if the PATH var isn't updated in this session
$ScriptPath = "`$($ScriptInfo.InstalledLocation)\$ScriptName.ps1"

Write-Host "[-] Starting Authentication (Phishing Resistant)..." -ForegroundColor Yellow
Write-Host "    A browser window will open shortly." -ForegroundColor Gray
Write-Host "    Running: `$ScriptPath" -ForegroundColor DarkGray

& `$ScriptPath -Online
"@

Set-Content -Path $PayloadFile -Value $PayloadContent

# --- 4. Hand off to PowerShell 7 ---
Write-Host "[-] Launching Modern Auth Flow..." -ForegroundColor Cyan
& "C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File $PayloadFile

Write-Host "[-] Done." -ForegroundColor Cyan