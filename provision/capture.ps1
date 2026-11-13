# Capture the app lineup from your already-configured "golden" box.
#
# Connects to the box, finds every app YOU installed (skips system apps),
# and pulls their APK files into the apks\ folder. After this, provision.ps1 /
# bootstrap.ps1 will install your exact lineup on every new box.
#
# How to run: right-click -> "Run with PowerShell"
# (or: powershell -ExecutionPolicy Bypass -File .\capture.ps1 [ip])

param([string] $Ip)

$DefaultIp = "192.168.1.218"   # <- your golden box

Set-Location $PSScriptRoot
Write-Host "=== Capture apps from golden box ===" -ForegroundColor Cyan

# Make sure adb exists (same auto-install as bootstrap.ps1)
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    $localAdb = Join-Path $PSScriptRoot "platform-tools\adb.exe"
    if (-not (Test-Path $localAdb)) {
        Write-Host ">> ADB not found - downloading Google platform-tools (~10 MB)..."
        $zip = Join-Path $env:TEMP "platform-tools.zip"
        Invoke-WebRequest "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip
        Expand-Archive $zip -DestinationPath $PSScriptRoot -Force
        Remove-Item $zip
    }
    $env:Path = "$PSScriptRoot\platform-tools;$env:Path"
}

if ([string]::IsNullOrWhiteSpace($Ip)) {
    $Ip = Read-Host "Golden box IP address [$DefaultIp]"
    if ([string]::IsNullOrWhiteSpace($Ip)) { $Ip = $DefaultIp }
}
$Box = "${Ip}:5555"

$out = adb connect $Box 2>&1
if ($out -notmatch "connected") {
    Write-Host "!! Cannot reach $Ip - is ADB debugging on and the box on this network?" -ForegroundColor Red
    Read-Host "Press Enter to close"; exit 1
}
$state = adb -s $Box get-state 2>$null
if ($state -ne "device") {
    Write-Host ">> Accept the 'Allow USB debugging' prompt on the TV (waiting 60s)..."
    foreach ($i in 1..30) { Start-Sleep 2; $state = adb -s $Box get-state 2>$null; if ($state -eq "device") { break } }
    if ($state -ne "device") { Write-Host "!! Never authorized." -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }
}

New-Item -ItemType Directory -Path "apks" -Force | Out-Null

# Every third-party (user-installed) package on the box
$packages = adb -s $Box shell pm list packages -3 | ForEach-Object { ($_ -replace "package:", "").Trim() } | Where-Object { $_ }
if (-not $packages) {
    Write-Host "No user-installed apps found on $Ip." -ForegroundColor Yellow
    Read-Host "Press Enter to close"; exit 0
}

Write-Host ">> Found $($packages.Count) user-installed app(s):" -ForegroundColor Green
$packages | ForEach-Object { Write-Host "   $_" }
Write-Host ""

$pulled = 0
foreach ($pkg in $packages) {
    # An app can have several APKs (split APKs); pull each one
    $paths = adb -s $Box shell pm path $pkg | ForEach-Object { ($_ -replace "package:", "").Trim() } | Where-Object { $_ }
    $i = 0
    foreach ($p in $paths) {
        $suffix = if ($paths.Count -gt 1) { ".split$i" } else { "" }
        $dest = "apks\$pkg$suffix.apk"
        Write-Host ">> Pulling $pkg$suffix ..."
        adb -s $Box pull $p $dest | Out-Null
        if ($LASTEXITCODE -eq 0) { $pulled++ } else { Write-Host "!! Failed to pull $p" -ForegroundColor Red }
        $i++
    }
}

adb disconnect $Box | Out-Null

Write-Host ""
Write-Host "================ DONE ================" -ForegroundColor Green
Write-Host "$pulled APK file(s) saved into $PSScriptRoot\apks"
Write-Host ""
Write-Host "NOTE: this captures the APPS, not their in-app settings (playlists,"
Write-Host "logins). For your IPTV player, use its own backup/export feature on the"
Write-Host "golden box, pull the backup file into configs\, and the provisioning"
Write-Host "script will copy it onto every new box to restore from."
Write-Host ""
Write-Host "Apps whose name ends in .splitN.apk are split APKs - provision.ps1"
Write-Host "installs plain APKs; if one of those fails to install on a new box,"
Write-Host "tell Claude and the install step can be upgraded to handle splits."
Read-Host "Press Enter to close"
