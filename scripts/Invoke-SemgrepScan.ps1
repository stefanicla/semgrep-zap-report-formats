<#
.SYNOPSIS
    Scans the demo app with Semgrep Community Edition and writes every output format from one scan.

.DESCRIPTION
    Runs the pinned Semgrep image with the local OWASP Top Ten ruleset snapshot
    (rules/owasp-top-ten.yaml). One `semgrep scan` writes all formats at once, using one
    --<format>-output flag per format. The container has no network access and metrics are off.

    Output: <OutDir>/report.* (one file per format), scan.log (console output) and
    scan.meta.json (versions, ruleset hash, command, duration, exit code).

.EXAMPLE
    .\scripts\Invoke-SemgrepScan.ps1
    Writes to reports\semgrep-<UTC>\.
#>
[CmdletBinding()]
param(
    [string]$OutDir,
    # Folder to scan. Default: the demo app.
    [string]$Target
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Assert-Docker

if (-not (Test-Path $script:RulesFile)) { throw 'The ruleset is missing. Run scripts\Update-SemgrepRules.ps1 first.' }
if (-not $Target) { $Target = $script:AppDir }
$Target = (Resolve-Path $Target).Path
if (-not $OutDir) { $OutDir = Join-Path $script:ReportsDir "semgrep-$(Get-UtcStamp)" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

# The ruleset is mounted at / : Semgrep prefixes rule IDs with the ruleset's folder ("rules.python...").
# The target is mounted as /src/<folder name>, and the scan runs from /src, so paths in the
# reports are relative (app/app.py) - as they would be in a repository.
$leaf = Split-Path -Leaf $Target
$formats = @(Get-FormatCatalog | Where-Object Tool -eq 'semgrep')
$semgrepArgs = @('scan', '--config', '/owasp-top-ten.yaml', '--metrics=off') +
    @($formats | ForEach-Object { "$($_.Option)=/out/$($_.File)" }) + @($leaf)

# No network: nothing leaves the machine. Without network access the version check stalls the scan
# for minutes, so it is switched off. --metrics=off disables usage metrics.
$dockerArgs = @('run', '--rm', '--network', 'none', '-e', 'SEMGREP_ENABLE_VERSION_CHECK=0', '-w', '/src') +
    (Get-BindMount $Target "/src/$leaf" -ReadOnly) +
    (Get-BindMount $script:RulesFile '/owasp-top-ten.yaml' -ReadOnly) +
    (Get-BindMount $OutDir '/out') +
    @($script:SemgrepImage, 'semgrep') + $semgrepArgs

Write-Host "Semgrep $script:SemgrepVersion - scanning $(Get-RepoRelativePath $Target)"
Write-Host "  semgrep $($semgrepArgs -join ' ')" -ForegroundColor DarkGray
$sw = [Diagnostics.Stopwatch]::StartNew()
& docker @dockerArgs *> (Join-Path $OutDir 'scan.log')
$exit = $LASTEXITCODE
$sw.Stop()

Write-Meta (Join-Path $OutDir 'scan.meta.json') @{
    tool          = 'semgrep'
    version       = $script:SemgrepVersion
    image         = $script:SemgrepImage
    target        = Get-RepoRelativePath $Target
    ruleset       = 'p/owasp-top-ten (local snapshot)'
    rulesetSha256 = (Get-FileHash -Algorithm SHA256 $script:RulesFile).Hash.ToLowerInvariant()
    command       = "semgrep $($semgrepArgs -join ' ')"
    dockerCommand = Format-Command 'docker' $dockerArgs
    durationSec   = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    exitCode      = $exit
}

# Exit code 0: scan done (findings do not change it). 1: findings with --error. Anything else: failure.
if ($exit -gt 1) {
    Get-Content (Join-Path $OutDir 'scan.log') -Tail 20 | Write-Host
    throw "Semgrep failed with exit code $exit. See $(Get-RepoRelativePath (Join-Path $OutDir 'scan.log'))."
}
$n = @((Get-Content -Raw (Join-Path $OutDir 'report.json') | ConvertFrom-Json).results).Count
Write-Host "Semgrep: $n findings in $([math]::Round($sw.Elapsed.TotalSeconds))s -> $(Get-RepoRelativePath $OutDir)"
$OutDir
