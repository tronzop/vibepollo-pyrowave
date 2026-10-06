# Install or upgrade Vibepollo from a local MSI on Mark-PC, keeping config + pairings.
# Must run as SYSTEM or from an interactive elevated prompt; msiexec over an SSH
# logon is refused, so from SSH use:  markpc\install.ps1 -ViaTask
param(
    [string]$Msi = "$PSScriptRoot\..\build\cpack_artifacts\Vibepollo.msi",
    [string]$Log = 'C:\ProgramData\vibepollo-install.log',
    [switch]$ViaTask
)
$ErrorActionPreference = 'Continue'
$Msi = (Resolve-Path $Msi).Path

if ($ViaTask) {
    Remove-Item $Log -ea 0
    $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Msi `"$Msi`" -Log `"$Log`""
    Register-ScheduledTask -TaskName 'VibepolloInstall' -Action $a -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask 'VibepolloInstall'
    do { Start-Sleep 5 } while ((Get-ScheduledTask 'VibepolloInstall').State -eq 'Running')
    Unregister-ScheduledTask 'VibepolloInstall' -Confirm:$false
    Get-Content $Log
    return
}

function L($m) { "$(Get-Date -Format s) $m" | Add-Content $Log }
$cfg = 'C:\Program Files\Apollo\config'
$bk = "C:\ProgramData\vibepollo-config-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
L "install $Msi"

# Back up config, credentials (server cert = client pairings) and state first.
if (Test-Path $cfg) { Copy-Item -Recurse $cfg $bk; L "config backed up to $bk" }

# First-time migration: Apollo's NSIS uninstaller. Its config backup above is
# restored after the MSI install, so paired clients keep working.
$apollo = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Apollo -ea 0
if ($apollo) {
    Stop-Service ApolloService -Force -ea 0; Get-Process sunshine -ea 0 | Stop-Process -Force -ea 0
    Start-Process 'C:\Program Files\Apollo\Uninstall.exe' -ArgumentList '/S' -Wait
    for ($i = 0; $i -lt 60 -and (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Apollo -ea 0); $i++) { Start-Sleep 2 }
    L 'Apollo uninstalled'
}

$p = Start-Process msiexec.exe -ArgumentList "/i `"$Msi`" /qn /norestart /l*v C:\ProgramData\vibepollo-msi.log" -Wait -PassThru
L "msiexec rc=$($p.ExitCode)"

# Put back anything the installer replaced or the Apollo uninstaller removed.
if (Test-Path $bk) {
    Stop-Service ApolloService -Force -ea 0; Get-Process sunshine -ea 0 | Stop-Process -Force -ea 0; Start-Sleep 2
    New-Item -ItemType Directory -Force "$cfg\credentials" | Out-Null
    foreach ($f in 'credentials\cacert.pem', 'credentials\cakey.pem', 'sunshine_state.json', 'apps.json', 'sunshine.conf') {
        if (Test-Path "$bk\$f") { Copy-Item -Force "$bk\$f" "$cfg\$f" }
    }
    L 'config restored'
}
Start-Service ApolloService -ea 0
Start-Sleep 15
L "ApolloService=$((Get-Service ApolloService -ea 0).Status)"
$latest = Get-ChildItem "$cfg\logs" -ea 0 | Sort-Object LastWriteTime | Select-Object -Last 1
if ($latest) { Get-Content $latest.FullName | Select-String 'Found .* encoder' | ForEach-Object { L $_.Line } }
L 'done'
