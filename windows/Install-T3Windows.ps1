[CmdletBinding()]
param(
    [string]$TargetDirectory = 'D:\Stuff\utils\agent'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
foreach ($name in @(
    'Start-T3CodeAtLogin.ps1',
    'Watch-T3VoiceServer.ps1',
    'Run-T3VoiceServer.sh'
)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $TargetDirectory $name) -Force
}
Write-Host "Installed T3 startup scripts in $TargetDirectory"
Write-Host 'Existing T3 and voice processes were left running.'