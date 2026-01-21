<#
.SYNOPSIS
    Bootstrap script for Intune Autopilot Enrollment via PowerShell 7.
    Fetches the latest PowerShell 7 release, verifies integrity, and performs
    Intune enrollment using modern authentication (Phishing Resistant).
#>

$ErrorActionPreference = "Stop"

Write-Host "[-] Initializing Intune Enrollment Bootstrap..." -ForegroundColor Cyan

# --- 1. TLS Setup ---
# Required for GitHub API and PSGallery connectivity
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# --- 2. Check/Install PowerShell 7 ---
$PwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"

if (-not (Test-Path $PwshPath)) {
    Write-Host "[-] PowerShell 7 not found. Fetching latest MSI..." -ForegroundColor Cyan
    
    try {
        # Fetch Release Info from GitHub API
        $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        
        # 1. Find the MSI Asset
        $MsiAsset = $LatestRelease.assets | Where-Object { $_.name -like "*-win-x64.msi" } | Select-Object -First 1
        if (-not $MsiAsset) { throw "Could not find MSI asset in latest release." }

        # 2. Extract Hash from API Metadata
        # Checks the 'digest' field provided by GitHub (e.g., "sha256:abcd...")
        if ($MsiAsset.digest) {
            $ExpectedHash = $MsiAsset.digest.Split(':')[-1]
            Write-Host "    Found Integrity Hash." -ForegroundColor DarkGray
        }
        else {
            Write-Warning "API did not return a SHA256 digest. Skipping security check."
            $ExpectedHash = $null
        }

        # 3. Download the MSI
        $TempMsi = "$env:TEMP\$($MsiAsset.name)"
        Write-Host "[-] Downloading $($MsiAsset.name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $MsiAsset.browser_download_url -OutFile $TempMsi

        # 4. Verify Integrity
        if ($ExpectedHash) {
            Write-Host "[-] Verifying SHA256 Checksum..." -ForegroundColor Cyan
            $CalculatedHash = (Get-FileHash -Path $TempMsi -Algorithm SHA256).Hash

            if ($CalculatedHash -ne $ExpectedHash) {
                Write-Error "HASH MISMATCH!"
                Write-Error "Expected: $ExpectedHash"
                Write-Error "Actual:   $CalculatedHash"
                throw "Security verification failed. The file may be corrupted."
            }
            Write-Host "    [OK] Hash Verified." -ForegroundColor Green
        }

        # 5. Install Silently
        Write-Host "[-] Installing PowerShell 7..." -ForegroundColor Cyan
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$TempMsi`" /quiet /norestart" -Wait
    }
    catch {
        Write-Error "Critical Failure installing PowerShell 7: $_"
        exit 1
    }
}

# --- 3. Prepare the Autopilot Payload ---
$PayloadFile = "$env:TEMP\IntuneEnrollment.ps1"

# We use Single Quotes (@') to prevent variable expansion errors.
$PayloadContent = @'
Write-Host "[-] Configuring PowerShell 7 Environment..." -ForegroundColor Green
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

# 1. Install NuGet Provider (Required for Install-Script)
if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
    Write-Host "[-] Installing NuGet Provider..." -ForegroundColor Green
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# 2. Install or Locate Autopilot Script
$ScriptName = "Get-WindowsAutopilotInfo"
$ScriptInfo = Get-InstalledScript -Name $ScriptName -ErrorAction SilentlyContinue

if (-not $ScriptInfo) {
    Write-Host "[-] Installing Get-WindowsAutopilotInfo..." -ForegroundColor Green
    Install-Script -Name $ScriptName -Force -Scope CurrentUser | Out-Null
    $ScriptInfo = Get-InstalledScript -Name $ScriptName
}

# 3. Execute using the Full Path (Fixes PATH visibility issues)
if ($ScriptInfo) {
    $ScriptPath = "$($ScriptInfo.InstalledLocation)\$ScriptName.ps1"

    Write-Host "[-] Starting Authentication (Phishing Resistant)..." -ForegroundColor Yellow
    Write-Host "    A browser window will open shortly." -ForegroundColor Gray
    
    & $ScriptPath -Online
}
else {
    Write-Error "Failed to locate the Autopilot script after installation."
}
'@

Set-Content -Path $PayloadFile -Value $PayloadContent

# --- 4. Handoff to PowerShell 7 ---
Write-Host "[-] Launching Modern Auth Flow..." -ForegroundColor Cyan

# Run the payload inside the new PS7 environment
& "C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File $PayloadFile

# --- 5. Cleanup ---
# Delete the temporary payload script to keep the system clean
if (Test-Path $PayloadFile) {
    Remove-Item -Path $PayloadFile -ErrorAction SilentlyContinue
}

Write-Host "[-] Process Complete." -ForegroundColor Cyan