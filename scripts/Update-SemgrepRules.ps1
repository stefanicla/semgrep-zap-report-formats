<#
.SYNOPSIS
    Downloads the free Semgrep "OWASP Top Ten" ruleset (p/owasp-top-ten) into rules/.

.DESCRIPTION
    Scans use this local snapshot instead of the registry, so they are reproducible and run
    without network access. The download date, URL, SHA-256 and rule count are written to
    rules/SOURCE.txt. Re-run this script to refresh the snapshot; results may then change.

    The rules are published under the Semgrep Rules License v1.0
    (https://semgrep.dev/legal/rules-license): internal use is allowed, redistribution
    in a competing product is not.

.EXAMPLE
    .\scripts\Update-SemgrepRules.ps1
#>
[CmdletBinding()]
param(
    [string]$Ruleset = 'p/owasp-top-ten'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')

$url = "https://semgrep.dev/c/$Ruleset"
$tmp = "$script:RulesFile.download"
New-Item -ItemType Directory -Force -Path (Split-Path $script:RulesFile) | Out-Null

Write-Host "Downloading $url"
# Without this header the registry answers PowerShell with JSON; YAML is easier to read and diff.
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -Headers @{ Accept = 'text/yaml' }
$head = Get-Content $tmp -TotalCount 1
if ($head -notmatch '^rules:') {
    Remove-Item $tmp
    throw "The download from $url is not a Semgrep ruleset (first line: '$head')."
}
Move-Item -Force $tmp $script:RulesFile

$hash  = (Get-FileHash -Algorithm SHA256 $script:RulesFile).Hash.ToLowerInvariant()
$count = @(Select-String -Path $script:RulesFile -Pattern '^- id: ').Count
@"
Ruleset   : $Ruleset (Semgrep Registry, free community rules)
URL       : $url
Downloaded: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC
SHA-256   : $hash
Rules     : $count (all languages; Semgrep runs only those matching the scanned files)
Licence   : Semgrep Rules License v1.0 - https://semgrep.dev/legal/rules-license
"@ | Set-Content -Encoding utf8 (Join-Path (Split-Path $script:RulesFile) 'SOURCE.txt')

Write-Host "Saved $count rules to $(Get-RepoRelativePath $script:RulesFile) (SHA-256 $hash)"
