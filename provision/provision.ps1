# Android box provisioning script (Windows PowerShell)
#
# Usage (from a PowerShell window in this folder):
#   .\provision.ps1 192.168.1.50                      one box
#   .\provision.ps1 192.168.1.50 192.168.1.51         several boxes
#   .\provision.ps1 -Csv customers.csv                 every box in a CSV (columns: name,ip)
#
# If Windows blocks the script, run once:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

param(
    [Parameter(ValueFromRemainingArguments = $true)] [string[]] $Ips,
    [string] $Csv
)

# ===== EDIT THESE FOR YOUR SETUP ============================================
# Package name of your main IPTV app, used for the launch test at the end.
#   TiviMate = ar.tvplayer.tv    IPTV Smarters Pro = com.nst.iptvsmarterstvbox
$MainAppPackage = "ar.tvplayer.tv"
$SetNeverSleep  = $true
# ============================================================================

Set-Location $PSScriptRoot
$Port = 5555
$Pass = @(); $Fail = @()

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "adb not found. Install Platform Tools and add the folder to PATH - see README.md step 1." -ForegroundColor Red
    exit 1
}

function Provision-Box([string]$Ip, [string]$Name = "") {
    $Box = "${Ip}:${Port}"
    Write-Host "`n=== Provisioning $Box $(if ($Name) {"($Name)"}) ===" -ForegroundColor Cyan

    $out = adb connect $Box 2>&1
    if ($out -notmatch "connected") {
        Write-Host "!! Cannot reach $Ip - is ADB debugging on and the box on this network?" -ForegroundColor Red
        $script:Fail += $Ip; return
    }

    # Wait for authorization (box shows an 'Allow USB debugging' prompt on first contact)
    $state = adb -s $Box get-state 2>$null
    if ($state -ne "device") {
        Write-Host ">> Waiting for you to accept the 'Allow USB debugging' prompt on the TV (60s)..."
        foreach ($i in 1..30) {
            Start-Sleep 2
            $state = adb -s $Box get-state 2>$null
            if ($state -eq "device") { break }
        }
        if ($state -ne "device") {
            Write-Host "!! $Ip never authorized - accept the prompt on the TV and re-run." -ForegroundColor Red
            $script:Fail += $Ip; return
        }
    }

    $ok = $true

    # 1. Install every APK in the kit (-r = reinstall ok, safe to re-run)
    Get-ChildItem "apks\*.apk" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host ">> Installing $($_.Name) ..."
        adb -s $Box install -r $_.FullName
        if ($LASTEXITCODE -ne 0) { Write-Host "!! Install failed: $($_.Name)" -ForegroundColor Red; $ok = $false }
    }

    # 2. Settings
    if ($SetNeverSleep) {
        adb -s $Box shell settings put system screen_off_timeout 2147483647 | Out-Null
    }

    # 3. Push any config files (playlists, backups, etc.) from configs\
    Get-ChildItem "configs\*" -File -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host ">> Pushing $($_.Name) to /sdcard/Download/ ..."
        adb -s $Box push $_.FullName /sdcard/Download/
        if ($LASTEXITCODE -ne 0) { $ok = $false }
    }

    # 4. Launch test of the main app
    if ($MainAppPackage) {
        Write-Host ">> Launch test: $MainAppPackage"
        adb -s $Box shell monkey -p $MainAppPackage -c android.intent.category.LAUNCHER 1 *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host ">> App launched OK" -ForegroundColor Green }
        else { Write-Host "!! App did not launch - check `$MainAppPackage at the top of this script" -ForegroundColor Red; $ok = $false }
    }

    adb disconnect $Box | Out-Null
    if ($ok) { $script:Pass += $Ip; Write-Host "=== $Ip DONE ===" -ForegroundColor Green }
    else     { $script:Fail += $Ip; Write-Host "=== $Ip FINISHED WITH ERRORS ===" -ForegroundColor Yellow }
}

if ($Csv) {
    if (-not (Test-Path $Csv)) { Write-Host "CSV not found: $Csv" -ForegroundColor Red; exit 1 }
    Import-Csv $Csv | ForEach-Object {
        if ($_.ip) { Provision-Box $_.ip.Trim() $_.name }
    }
}
elseif ($Ips) {
    foreach ($ip in $Ips) { Provision-Box $ip }
}
else {
    Write-Host "Usage: .\provision.ps1 <ip> [<ip> ...]   or   .\provision.ps1 -Csv customers.csv"
    exit 1
}

Write-Host "`n================ SUMMARY ================"
Write-Host "OK ($($Pass.Count)):     $($Pass -join ', ')"
Write-Host "FAILED ($($Fail.Count)): $($Fail -join ', ')"
