[CmdletBinding()]
param([switch]$Once)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$voiceUrl = 'http://127.0.0.1:8001/'
$serverScript = '/mnt/d/Stuff/utils/agent/Run-T3VoiceServer.sh'
$logPath = Join-Path $PSScriptRoot 't3-voice-watch.log'
$serverOutputPath = Join-Path $PSScriptRoot 't3-voice-server.stdout.log'
$serverErrorPath = Join-Path $PSScriptRoot 't3-voice-server.stderr.log'
$mutex = [System.Threading.Mutex]::new($false, 'Local\T3VoiceServerWatch')

function Write-WatchLog([string]$Message) {
    $timestamp = [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:ss.fffzzz')
    Add-Content -LiteralPath $logPath -Value "$timestamp $Message" -Encoding UTF8
}

function Test-VoiceServer {
    try {
        $response = Invoke-WebRequest -Uri $voiceUrl -UseBasicParsing -TimeoutSec 3
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

$ownsMutex = try { $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $true }
if (-not $ownsMutex) {
    $mutex.Dispose()
    exit 0
}

try {
    $ownedProcess = $null
    do {
        if (-not (Test-VoiceServer)) {
            if ($null -ne $ownedProcess -and -not $ownedProcess.HasExited) {
                Write-WatchLog "Voice server stopped responding; terminating owned WSL process $($ownedProcess.Id)."
                Stop-Process -Id $ownedProcess.Id -Force -ErrorAction SilentlyContinue
                $ownedProcess.WaitForExit(5000) | Out-Null
            }

            try {
                $ownedProcess = Start-Process -FilePath 'wsl.exe' -ArgumentList @(
                    '-d', 'ubuntu-test', '-u', 'root', '--', 'bash', $serverScript
                ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $serverOutputPath -RedirectStandardError $serverErrorPath
                Write-WatchLog "Started voice server through WSL process $($ownedProcess.Id)."
            }
            catch {
                Write-WatchLog "Could not start voice server: $($_.Exception.Message)"
            }

            for ($attempt = 0; $attempt -lt 15 -and -not (Test-VoiceServer); $attempt++) {
                Start-Sleep -Seconds 1
            }
            if (-not (Test-VoiceServer)) {
                Write-WatchLog 'Voice server is still unavailable. The next check will retry.'
            }
        }

        if ($Once) {
            if (Test-VoiceServer) { exit 0 }
            exit 1
        }
        Start-Sleep -Seconds 5
    } while ($true)
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
