# setup-remote-access.ps1
# One-shot setup so this Windows PC can be reached and controlled from your phone
# and your other PC. Run it via SETUP.bat (double-click). Safe to run again.
#
# What it does:
#   1. Installs Tailscale (private network) and signs in (unattended mode)
#   2. Installs RustDesk (screen control) as a service, sets a permanent password,
#      enables direct IP access (so it works over Tailscale)
#   3. Installs the Claude desktop app and creates C:\Claude as a working folder
#   4. Power settings: no sleep on AC, no hibernate, Fast Startup off
#   5. Network card: allows Wake-on-LAN (BIOS still needs to be done by hand)
#   6. Optional: OpenSSH server, reachable ONLY from your Tailscale devices
#   7. Desktop shortcuts: Shutdown / Restart
#   8. Writes a report to C:\Claude\setup-report.txt

$ErrorActionPreference = 'Continue'

# ---------- self-elevate ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$work = 'C:\Claude'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$log = Join-Path $work 'setup-log.txt'
Start-Transcript -Path $log -Append | Out-Null

function Step($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  [OK] $t" -ForegroundColor Green }
function Warn($t) { Write-Host "  [!!] $t" -ForegroundColor Yellow }

$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

function Install-Winget($id) {
    if (-not $hasWinget) { return $false }
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements --scope machine 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { return $true }  # 0 = ok, -1978335189 = already installed
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Host
    return ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189)
}

function Download($url, $file) {
    $dest = Join-Path $env:TEMP $file
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    return $dest
}

Write-Host "Remote access setup for: $env:COMPUTERNAME" -ForegroundColor White
$rdPass = Read-Host "Choose a RustDesk password for THIS PC (long, 12+ characters; you'll type it on your phone)"
$wantSsh = (Read-Host "Also enable command-line access (OpenSSH, Tailscale-only)? Recommended: Y  [Y/N]") -match '^[Yy]'

# ---------- 1. Tailscale ----------
Step "1/7 Tailscale"
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (-not (Test-Path $ts)) {
    if (-not (Install-Winget 'Tailscale.Tailscale')) {
        $f = Download 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' 'tailscale-setup.exe'
        Start-Process $f -ArgumentList '/quiet' -Wait
    }
}
if (Test-Path $ts) {
    Ok "Tailscale installed"
    Write-Host "  A browser window may open: sign in with the SAME account on all your devices." -ForegroundColor White
    & $ts up --unattended --reset 2>&1 | Out-Host
    $tsIp = (& $ts ip -4 2>$null | Select-Object -First 1)
    if ($tsIp) { Ok "Tailscale address: $tsIp" } else { Warn "Not signed in yet. Open Tailscale from the tray icon and log in, then re-run this script." }
} else { Warn "Tailscale install failed. Install it from https://tailscale.com/download" }

# ---------- 2. RustDesk ----------
Step "2/7 RustDesk"
$rd = 'C:\Program Files\RustDesk\rustdesk.exe'
if (-not (Test-Path $rd)) {
    if (-not (Install-Winget 'RustDesk.RustDesk')) {
        try {
            $rel = Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -UseBasicParsing
            $asset = $rel.assets | Where-Object { $_.name -match 'x86_64\.exe$' } | Select-Object -First 1
            $f = Download $asset.browser_download_url 'rustdesk-setup.exe'
            Start-Process $f -ArgumentList '--silent-install' -Wait
            Start-Sleep 15
        } catch { Warn "RustDesk download failed: $_" }
    }
}
if (Test-Path $rd) {
    Ok "RustDesk installed"
    Start-Process $rd -ArgumentList '--install-service' -Wait -ErrorAction SilentlyContinue
    Start-Sleep 5
    if ($rdPass) { Start-Process $rd -ArgumentList "--password `"$rdPass`"" -Wait; Ok "Permanent password set" }
    Start-Process $rd -ArgumentList '--option direct-server Y' -Wait -ErrorAction SilentlyContinue
    # Also write the option into the service's config so it survives
    $cfgDirs = @('C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config',
                 "$env:APPDATA\RustDesk\config")
    foreach ($d in $cfgDirs) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        $c = Join-Path $d 'RustDesk2.toml'
        $txt = if (Test-Path $c) { Get-Content $c -Raw } else { '' }
        if ($txt -notmatch 'direct-server') {
            if ($txt -notmatch '\[options\]') { $txt = $txt.TrimEnd() + "`r`n`r`n[options]`r`n" }
            $txt = $txt -replace '\[options\]\s*', "[options]`r`ndirect-server = 'Y'`r`n"
            Set-Content -Path $c -Value $txt -Encoding UTF8
        }
    }
    Restart-Service -Name RustDesk -ErrorAction SilentlyContinue
    $rdId = (& $rd --get-id 2>$null | Out-String).Trim()
    Ok "Direct IP access enabled (connect using the Tailscale address)"
    if ($rdId) { Ok "RustDesk ID: $rdId" }
    # Allow RustDesk direct port from Tailscale only
    New-NetFirewallRule -DisplayName 'RustDesk direct (Tailscale only)' -Direction Inbound -Protocol TCP `
        -LocalPort 21118 -RemoteAddress 100.64.0.0/10 -Action Allow -ErrorAction SilentlyContinue | Out-Null
} else { Warn "RustDesk install failed. Install it from https://rustdesk.com" }

# ---------- 3. Claude desktop ----------
Step "3/7 Claude desktop app"
if (Install-Winget 'Anthropic.Claude') { Ok "Claude installed" }
else { Warn "Opening the download page: install Claude by hand."; Start-Process 'https://claude.ai/download' }
Ok "Working folder for Claude: $work"

# ---------- 4. Power ----------
Step "4/7 Power settings (stay reachable)"
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 15
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' `
    -Name HiberbootEnabled -Value 0 -PropertyType DWord -Force | Out-Null
Ok "No sleep on AC power, Fast Startup disabled"

# ---------- 5. Wake-on-LAN (Windows side) ----------
Step "5/7 Wake-on-LAN (Windows side)"
$nics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up'
foreach ($n in $nics) {
    Set-NetAdapterPowerManagement -Name $n.Name -WakeOnMagicPacket Enabled -ErrorAction SilentlyContinue
    foreach ($p in 'Wake on Magic Packet','Wake on magic packet','WakeOnMagicPacket') {
        Set-NetAdapterAdvancedProperty -Name $n.Name -DisplayName $p -DisplayValue 'Enabled' -ErrorAction SilentlyContinue
    }
    powercfg /deviceenablewake "$($n.InterfaceDescription)" 2>$null
    Ok "$($n.Name) ($($n.MediaType)) MAC=$($n.MacAddress)"
}
Warn "BIOS settings can't be changed from Windows: see the guide, Phase 4."

# ---------- 6. OpenSSH (optional) ----------
Step "6/7 Command-line access (OpenSSH)"
if ($wantSsh) {
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
    if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null }
    Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service sshd -ErrorAction SilentlyContinue
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue |
        Set-NetFirewallRule -RemoteAddress 100.64.0.0/10
    if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH (Tailscale only)' -Direction Inbound `
            -Protocol TCP -LocalPort 22 -RemoteAddress 100.64.0.0/10 -Action Allow | Out-Null
    }
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
        -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null
    Ok "SSH on port 22, reachable only from your Tailscale devices. Login: $env:USERNAME + your Windows password"
} else { Ok "Skipped" }

# ---------- 7. Shortcuts ----------
Step "7/7 Desktop shortcuts"
$desk = [Environment]::GetFolderPath('CommonDesktopDirectory')
$sh = New-Object -ComObject WScript.Shell
foreach ($s in @(@{n='SHUTDOWN now';a='/s /t 5'}, @{n='RESTART now';a='/r /t 5'})) {
    $l = $sh.CreateShortcut((Join-Path $desk "$($s.n).lnk"))
    $l.TargetPath = 'C:\Windows\System32\shutdown.exe'; $l.Arguments = $s.a
    $l.IconLocation = 'C:\Windows\System32\shell32.dll,27'; $l.Save()
}
Ok "Shortcuts created on the desktop"

# ---------- report ----------
$report = @"
REMOTE ACCESS REPORT - $(Get-Date)
Computer name   : $env:COMPUTERNAME
Windows user    : $env:USERNAME
Windows version : $((Get-CimInstance Win32_OperatingSystem).Caption)
Tailscale IP    : $tsIp
RustDesk ID     : $rdId
SSH enabled     : $wantSsh
Network cards   :
$(($nics | ForEach-Object { "  $($_.Name) | $($_.MediaType) | MAC $($_.MacAddress)" }) -join "`r`n")

From your phone (Tailscale ON):
  RustDesk -> type $tsIp -> Connect -> your RustDesk password
  SSH      -> ssh $env:USERNAME@$tsIp
"@
Set-Content -Path (Join-Path $work 'setup-report.txt') -Value $report
Write-Host ""; Write-Host $report -ForegroundColor White
Write-Host "Report saved to $work\setup-report.txt  (send it to Claude, but NOT your passwords)" -ForegroundColor Green
Write-Host "Restart the PC once so every setting takes effect." -ForegroundColor Yellow
Stop-Transcript | Out-Null
Read-Host "Press Enter to close"
