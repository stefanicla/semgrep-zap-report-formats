<#
.SYNOPSIS
    Runs the demo app in a container, scans it with OWASP ZAP and writes every report template from one scan.

.DESCRIPTION
    1. Builds the demo app image (app/Dockerfile) and starts it on an internal Docker network
       (no internet, no port published on the host). The container is read-only, with no
       Linux capabilities.
    2. Runs the pinned ZAP image with the Automation Framework plan config/zap-plan.yaml:
       spider, passive scan, a short active scan, then one report job per template.
       ZAP runs with -silent (no update checks or other outgoing calls).
    3. Stops the app and removes the network.

    Output: <OutDir>/report.* (one file per template, some with a resource folder), scan.log
    and scan.meta.json.

    The active scan sends real attacks (SQL injection, XSS, command injection payloads).
    Only point it at systems you own or are allowed to test.

.EXAMPLE
    .\scripts\Invoke-ZapScan.ps1
    Writes to reports\zap-<UTC>\.
#>
[CmdletBinding()]
param(
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Assert-Docker

$plan = Join-Path $script:RepoRoot 'config\zap-plan.yaml'
if (-not $OutDir) { $OutDir = Join-Path $script:ReportsDir "zap-$(Get-UtcStamp)" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$log = Join-Path $OutDir 'scan.log'

function Invoke-Docker {
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw "docker $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

# --- 1. Demo app --------------------------------------------------------------------------
Write-Host 'Building the demo app image'
Invoke-Docker build --quiet --tag $script:AppImage $script:AppDir | Out-Null
docker rm --force demo-app *> $null
docker network inspect $script:LabNetwork *> $null
if ($LASTEXITCODE -ne 0) { Invoke-Docker network create --internal $script:LabNetwork | Out-Null }

$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    Invoke-Docker run --detach --rm --name demo-app --network $script:LabNetwork --read-only --cap-drop ALL `
        --security-opt no-new-privileges --memory 256m --pids-limit 100 $script:AppImage | Out-Null
    $deadline = (Get-Date).AddSeconds(30)
    while (-not ((docker logs demo-app 2>&1) -match 'Running on')) {
        if ((Get-Date) -gt $deadline) { throw 'The demo app did not start within 30 seconds.' }
        Start-Sleep -Milliseconds 500
    }

    # --- 2. ZAP ---------------------------------------------------------------------------
    # After the plan, the container lists what it wrote, so files that vanish on the host can be told apart.
    $zapCmd = 'zap.sh -cmd -silent -autorun /zap/wrk/zap-plan.yaml; rc=$?; echo "FILES WRITTEN BY ZAP:"; ls -1 /zap/wrk/out; exit $rc'
    $dockerArgs = @('run', '--rm', '--network', $script:LabNetwork) +
        (Get-BindMount $plan '/zap/wrk/zap-plan.yaml' -ReadOnly) +
        (Get-BindMount $OutDir '/zap/wrk/out') +
        @($script:ZapImage, 'sh', '-c', $zapCmd)

    Write-Host "ZAP $script:ZapVersion - scanning http://demo-app:5000 (about 2-3 minutes)"
    & docker @dockerArgs *> $log
    $exit = $LASTEXITCODE
}
finally {
    docker stop demo-app *> $null
    docker network rm $script:LabNetwork *> $null
}
$sw.Stop()

Write-Meta (Join-Path $OutDir 'scan.meta.json') @{
    tool          = 'zap'
    version       = $script:ZapVersion
    image         = $script:ZapImage
    target        = 'http://demo-app:5000 (app/, internal Docker network)'
    plan          = 'config/zap-plan.yaml'
    command       = 'zap.sh -cmd -silent -autorun /zap/wrk/zap-plan.yaml'
    dockerCommand = Format-Command 'docker' $dockerArgs
    durationSec   = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    exitCode      = $exit
}

if ($exit -ne 0 -or -not (Select-String -Path $log -Pattern 'Automation plan succeeded' -Quiet)) {
    Get-Content $log -Tail 30 | Write-Host
    throw "ZAP failed with exit code $exit. See $(Get-RepoRelativePath $log)."
}

# A report ZAP wrote that is not on disk was most likely removed by antivirus software:
# the reports contain attack payloads (XSS, command injection) as evidence.
$inContainer = @((Get-Content $log) -split "`n" | ForEach-Object Trim)
foreach ($f in Get-FormatCatalog | Where-Object Tool -eq 'zap') {
    if (-not (Test-Path (Join-Path $OutDir $f.File))) {
        $why = if ($inContainer -contains $f.File) { 'ZAP wrote it, but it is gone from disk: probably removed by antivirus software (see docs/report-formats.md, Pitfalls)' } else { 'ZAP did not write it' }
        Write-Warning "$($f.File) is missing. $why."
    }
}

$n = @((Get-Content -Raw (Join-Path $OutDir 'report.traditional.json') | ConvertFrom-Json).site | ForEach-Object { $_.alerts }).Count
Write-Host "ZAP: $n alert types in $([math]::Round($sw.Elapsed.TotalSeconds))s -> $(Get-RepoRelativePath $OutDir)"
$OutDir
