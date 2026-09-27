[CmdletBinding()]
param(
    [switch]$SkipMinimize
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$t3Executable = "C:\Users\Anton\AppData\Local\Programs\t3code\T3 Code (Alpha).exe"
$t3WorkingDirectory = Split-Path -Parent $t3Executable
$logPath = Join-Path $PSScriptRoot "startup.log"
$voiceWatchScript = Join-Path $PSScriptRoot 'Watch-T3VoiceServer.ps1'
$env:T3_SPEECH_OPENVINO_URL = 'http://127.0.0.1:8001/'

function Write-StartupLog {
    param([string]$Message)

    $timestamp = [DateTimeOffset]::Now.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    Add-Content -LiteralPath $logPath -Value "$timestamp $Message" -Encoding UTF8
}

try {
    if (-not (Test-Path -LiteralPath $voiceWatchScript -PathType Leaf)) {
        throw "Voice server monitor was not found at '$voiceWatchScript'."
    }
    Start-Process -FilePath 'pwsh.exe' -ArgumentList "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$voiceWatchScript`"" -WindowStyle Hidden | Out-Null
    Write-StartupLog 'Started voice server monitor.'

    if (-not (Test-Path -LiteralPath $t3Executable -PathType Leaf)) {
        throw "T3 Code executable was not found at '$t3Executable'."
    }

    $rootProcesses = @(
        Get-CimInstance Win32_Process -Filter "Name = 'T3 Code (Alpha).exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ExecutablePath -eq $t3Executable -and
                $_.CommandLine -notmatch "--type=" -and
                $_.CommandLine -notmatch "apps\\server\\dist\\bin\.mjs"
            }
    )

    if ($rootProcesses.Count -eq 0) {
        $startParameters = @{
            FilePath         = $t3Executable
            WorkingDirectory = $t3WorkingDirectory
            WindowStyle      = "Minimized"
            PassThru         = $true
        }
        $startedProcess = Start-Process @startParameters
        Write-StartupLog "Started T3 Code process $($startedProcess.Id)."
    }
    else {
        Write-StartupLog "T3 Code was already running as process $($rootProcesses[0].ProcessId)."
    }

    if ($SkipMinimize) {
        Write-StartupLog "Skipped window minimization for verification."
        exit 0
    }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class T3CodeStartupWindow
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

    $deadline = [DateTimeOffset]::Now.AddSeconds(90)
    $windowProcess = $null

    while ([DateTimeOffset]::Now -lt $deadline) {
        $windowProcess = Get-Process -Name "T3 Code (Alpha)" -ErrorAction SilentlyContinue |
            Where-Object {
                $_.MainWindowHandle -ne [IntPtr]::Zero -and
                [T3CodeStartupWindow]::IsWindowVisible($_.MainWindowHandle)
            } |
            Select-Object -First 1

        if ($null -ne $windowProcess) {
            break
        }

        Start-Sleep -Milliseconds 200
    }

    if ($null -eq $windowProcess) {
        throw "T3 Code did not expose a visible window within 90 seconds."
    }

    # SW_MINIMIZE = 6. Repeat once because Electron may issue a final show call
    # immediately after its ready-to-show event.
    [void][T3CodeStartupWindow]::ShowWindowAsync($windowProcess.MainWindowHandle, 6)
    Start-Sleep -Milliseconds 750
    [void][T3CodeStartupWindow]::ShowWindowAsync($windowProcess.MainWindowHandle, 6)
    Write-StartupLog "Minimized T3 Code window for process $($windowProcess.Id)."
}
catch {
    Write-StartupLog "ERROR: $($_.Exception.Message)"
    exit 1
}
