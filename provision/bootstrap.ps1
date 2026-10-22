# One-click setup + provisioning for Windows.
#
# What it does, all by itself:
#   1. Downloads ADB (Google platform-tools) into this folder if it's not installed
#   2. Checks the apks/ folder and tells you if it's empty
#   3. Runs provision.ps1 against your box
#
# How to run: right-click this file -> "Run with PowerShell"
# (If Windows blocks it: open PowerShell here and run
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 )

$DefaultIp = "192.168.1.218"   # <- your box; just press Enter at the prompt to use it

Set-Location $PSScriptRoot
Write-Host "=== IPTV Box Provisioning Bootstrap ===" -ForegroundColor Cyan

# --- 1. Make sure adb exists -------------------------------------------------
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    $localAdb = Join-Path $PSScriptRoot "platform-tools\adb.exe"
    if (-not (Test-Path $localAdb)) {
        Write-Host ">> ADB not found - downloading Google platform-tools (~10 MB)..."
        $zip = Join-Path $env:TEMP "platform-tools.zip"
        Invoke-WebRequest "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip
        Expand-Archive $zip -DestinationPath $PSScriptRoot -Force
        Remove-Item $zip
        Write-Host ">> ADB installed into $PSScriptRoot\platform-tools" -ForegroundColor Green
    }
    $env:Path = "$PSScriptRoot\platform-tools;$env:Path"
}
Write-Host ">> Using adb: $((Get-Command adb).Source)"

# --- 2. Check the APK kit ----------------------------------------------------
$apks = Get-ChildItem "apks\*.apk" -ErrorAction SilentlyContinue
if (-not $apks) {
    Write-Host ""
    Write-Host "!! The apks folder is EMPTY - nothing would be installed." -ForegroundColor Yellow
    Write-Host "   Download your apps into $PSScriptRoot\apks first, e.g.:"
    Write-Host "   - Downloader by AFTVnews: https://www.apkmirror.com/apk/aftvnews-com/downloader-by-aftvnews/"
    Write-Host "   - Your IPTV player (TiviMate / Smarters / etc.) from its official site or APKMirror"
    Write-Host ""
    $go = Read-Host "Continue anyway (settings/config only)? [y/N]"
    if ($go -notmatch '^[Yy]') { exit 0 }
} else {
    Write-Host ">> APK kit: $($apks.Name -join ', ')"
}

# --- 3. Run the provisioning -------------------------------------------------
Write-Host ""
Write-Host "Before continuing, on the box make sure:" -ForegroundColor Cyan
Write-Host "  - It's on the SAME Wi-Fi as this computer"
Write-Host "  - ADB Debugging is ON (Settings -> My Fire TV / Device Preferences -> Developer Options)"
Write-Host "  - You have the TV remote handy to click 'Allow' when asked"
Write-Host ""
$ip = Read-Host "Box IP address [$DefaultIp]"
if ([string]::IsNullOrWhiteSpace($ip)) { $ip = $DefaultIp }

& "$PSScriptRoot\provision.ps1" $ip

Write-Host ""
Read-Host "Press Enter to close"
