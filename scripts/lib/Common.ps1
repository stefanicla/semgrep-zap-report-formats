# Shared helpers for the Semgrep + ZAP report-formats PoC. Dot-source it: . "$PSScriptRoot\lib\Common.ps1"

Set-StrictMode -Version Latest

# --- Pinned tools -----------------------------------------------------------------------------
# Images are pinned by digest: a tag can be moved, a digest cannot. To upgrade, pull the new
# image, check its version, then update both values here and in README.md.
$script:SemgrepVersion = '1.182.1'
$script:SemgrepImage   = 'semgrep/semgrep@sha256:451b3d875c00dac7ed5db5293e584a07de11449a409c10b3c2d2652f429630b6'
$script:ZapVersion     = '2.17.0'
$script:ZapImage       = 'ghcr.io/zaproxy/zaproxy@sha256:7aaa659b0d43078febd82e29bad112285c370727e86ab8340444220e17d9f0d2'

$script:RepoRoot    = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:RulesFile   = Join-Path $script:RepoRoot 'rules\owasp-top-ten.yaml'
$script:ReportsDir  = Join-Path $script:RepoRoot 'reports'
$script:AppDir      = Join-Path $script:RepoRoot 'app'
$script:AppImage    = 'semgrep-zap-demo-app:local'
$script:LabNetwork  = 'semgrep-zap-lab'

# --- Format catalogue -------------------------------------------------------------------------
# One entry per native output format. "Option" is the Semgrep flag or the ZAP report template.
# Word (measured with Word 365): yes = opens as a tidy document with real tables; poor = opens, but long, raw or loses parts; no = not a Word input.
function Get-FormatCatalog {
    @(
        # Semgrep Community Edition: one scan, every format written at once with --<format>-output.
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'text';           Option = '--text-output';           File = 'report.txt';                  Kind = 'text';   For = 'People at a console';                 OpenWith = 'Text editor';              Word = 'poor'; Description = 'The default console output: each finding with its rule, message and code snippet, then a summary.' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'json';           Option = '--json-output';           File = 'report.json';                 Kind = 'text';   For = 'Automation, archiving (the baseline)'; OpenWith = 'VS Code, any editor';      Word = 'no';   Description = 'Semgrep''s complete native format: every finding with rule ID, file, line, severity, message, metadata (CWE, OWASP, confidence). Without a Semgrep login the code line and fingerprint read requires login.' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'sarif';          Option = '--sarif-output';          File = 'report.sarif';                Kind = 'text';   For = 'GitHub code scanning, IDEs';          OpenWith = 'VS Code (SARIF Viewer)';   Word = 'no';   Description = 'SARIF 2.1.0, the standard exchange format for static analysis. Uploaded to GitHub code scanning or opened in an IDE. Embeds the definition of every rule in the ruleset (1 MB here).' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'gitlab-sast';    Option = '--gitlab-sast-output';    File = 'report.gitlab-sast.json';     Kind = 'text';   For = 'GitLab security dashboard (SAST)';    OpenWith = 'GitLab, any editor';       Word = 'no';   Description = 'GitLab SAST report (artifacts:reports:sast). File, line, severity and rule ID; no CWE and no code.' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'gitlab-secrets'; Option = '--gitlab-secrets-output'; File = 'report.gitlab-secrets.json';  Kind = 'text';   For = 'GitLab secret detection';             OpenWith = 'GitLab, any editor';       Word = 'no';   Description = 'GitLab secret detection report (artifacts:reports:secret_detection). Caution: it lists every finding as a secret, not only secrets.' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'junit-xml';      Option = '--junit-xml-output';      File = 'report.junit.xml';            Kind = 'text';   For = 'CI test results';                     OpenWith = 'Jenkins, Azure DevOps, GitLab'; Word = 'no'; Description = 'JUnit XML: each finding is a failed test case, so a CI server shows it as a test result.' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'emacs';          Option = '--emacs-output';          File = 'report.emacs.txt';            Kind = 'text';   For = 'Editors, grep';                       OpenWith = 'Emacs, any editor';        Word = 'no';   Description = 'One line per finding: file:line:column:severity(rule):message. Uses the short rule name only, so two rules can look the same.' }
        [pscustomobject]@{ Tool = 'semgrep'; Name = 'vim';            Option = '--vim-output';            File = 'report.vim.txt';              Kind = 'text';   For = 'Editors, grep';                       OpenWith = 'Vim quickfix, any editor'; Word = 'no';   Description = 'One line per finding, in the Vim quickfix format, with the full rule ID.' }

        # OWASP ZAP: one scan, one "report" job per template of the Report Generation add-on.
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-html';      Option = 'traditional-html';      File = 'report.traditional.html';      Kind = 'text';   For = 'People, Word documents';             OpenWith = 'Browser or Word';      Word = 'yes';  Description = 'The classic ZAP report: a summary table, then each alert with description, URLs, evidence and solution.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-html-plus'; Option = 'traditional-html-plus'; File = 'report.traditional-plus.html'; Kind = 'text';   For = 'Developers reproducing an issue';    OpenWith = 'Browser';              Word = 'poor'; Description = 'As traditional-html, plus the HTTP requests and responses behind each alert. Needs its resource folder next to it.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-json';      Option = 'traditional-json';      File = 'report.traditional.json';      Kind = 'text';   For = 'Automation, archiving (the baseline)'; OpenWith = 'VS Code, any editor'; Word = 'no';   Description = 'Every alert per site, with risk, confidence, CWE, instances (URL, parameter, attack, evidence) and solution.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-json-plus'; Option = 'traditional-json-plus'; File = 'report.traditional-plus.json'; Kind = 'text';   For = 'Automation that needs the HTTP traffic'; OpenWith = 'VS Code, any editor'; Word = 'no'; Description = 'As traditional-json, plus the request and response of each instance.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-xml';       Option = 'traditional-xml';       File = 'report.traditional.xml';       Kind = 'text';   For = 'Older tools that read ZAP XML';      OpenWith = 'Any editor';           Word = 'no';   Description = 'The same content as traditional-json, in XML. Many older integrations (for example DefectDojo) read it.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-xml-plus';  Option = 'traditional-xml-plus';  File = 'report.traditional-plus.xml';  Kind = 'text';   For = 'Older tools that need the HTTP traffic'; OpenWith = 'Any editor';        Word = 'no';   Description = 'As traditional-xml, plus requests and responses.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-md';        Option = 'traditional-md';        File = 'report.traditional.md';        Kind = 'text';   For = 'Wikis, pull requests, tickets';      OpenWith = 'GitHub, GitLab, VS Code preview'; Word = 'poor'; Description = 'Markdown: summary table and alert details. Renders in GitHub, GitLab, Confluence, VS Code.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'traditional-pdf';       Option = 'traditional-pdf';       File = 'report.pdf';                   Kind = 'binary'; For = 'Sending to someone, archiving';      OpenWith = 'PDF reader';           Word = 'no';  ; Description = 'A printable PDF of the traditional report. Ready to send, but not editable.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'modern';                Option = 'modern';                File = 'report.modern.html';           Kind = 'text';   For = 'People: interactive review';         OpenWith = 'Browser';              Word = 'poor'; Description = 'A modern, interactive HTML report with charts; it also includes the HTTP requests and responses. Needs its resource folder next to it.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'risk-confidence-html';  Option = 'risk-confidence-html';  File = 'report.risk-confidence.html';  Kind = 'text';   For = 'Triage: risk x confidence matrix';   OpenWith = 'Browser';              Word = 'poor'; Description = 'HTML report organised as a risk x confidence matrix, then the alerts. Needs its resource folder next to it.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'high-level-report';     Option = 'high-level-report';     File = 'report.high-level.html';       Kind = 'text';   For = 'Managers: one-page summary';         OpenWith = 'Browser';              Word = 'poor'; Description = 'A short management summary: counts per risk level and the alert list. The charts need JavaScript and are lost in Word. Needs its resource folder next to it.' }
        [pscustomobject]@{ Tool = 'zap'; Name = 'sarif-json';            Option = 'sarif-json';            File = 'report.sarif.json';            Kind = 'text';   For = 'GitHub code scanning, SARIF tools';  OpenWith = 'VS Code (SARIF Viewer)'; Word = 'no'; Description = 'SARIF 2.1.0. GitHub code scanning accepts it, but DAST alerts point to URLs, not to source files.' }
    )
}

# --- Small helpers ----------------------------------------------------------------------------
function Get-UtcStamp { (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }

function Get-RepoRelativePath([string]$Path) {
    if ($Path -and $Path.StartsWith($script:RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return '.' + $Path.Substring($script:RepoRoot.Length)
    }
    $Path
}

function ConvertTo-HtmlText([string]$Text) { [System.Net.WebUtility]::HtmlEncode($Text) }

function Assert-Docker {
    docker version --format '{{.Server.Version}}' *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker is not running. Start Docker Desktop and try again.' }
}

# docker --mount argument for a bind mount (handles spaces in Windows paths).
function Get-BindMount([string]$Source, [string]$Target, [switch]$ReadOnly) {
    $m = "type=bind,source=$Source,target=$Target"
    if ($ReadOnly) { $m += ',readonly' }
    '--mount', $m
}

# Prints a command so it can be copied. Arguments with spaces are quoted.
function Format-Command([string]$Exe, [string[]]$Arguments) {
    $parts = @($Exe) + $Arguments | ForEach-Object { if ($_ -match '[\s"]') { "'" + ($_ -replace "'", "''") + "'" } else { $_ } }
    $parts -join ' '
}

function Write-Meta([string]$Path, [hashtable]$Data) {
    $Data['generatedAtUtc'] = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    [pscustomobject]$Data | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $Path
}

function Get-NewestFolder([string]$Filter) {
    Get-ChildItem $script:ReportsDir -Directory -Filter $Filter -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
}

# --- Presence check ---------------------------------------------------------------------------
# The baseline is the tool's JSON report. Semgrep findings are identified by rule ID, ZAP alerts by
# alert name. For each format we count how many of the baseline identifiers appear in the file.
# It is a quick hint of what a format carries; open the files to confirm.
function Get-BaselineId([string]$Tool, [string]$Dir) {
    if ($Tool -eq 'semgrep') {
        $j = Get-Content -Raw (Join-Path $Dir 'report.json') | ConvertFrom-Json
        return @($j.results | ForEach-Object { $_.check_id } | Sort-Object -Unique)
    }
    $j = Get-Content -Raw (Join-Path $Dir 'report.traditional.json') | ConvertFrom-Json
    @($j.site | ForEach-Object { $_.alerts } | ForEach-Object { $_.alert } | Sort-Object -Unique)
}

# Presence check of every format of one tool, in a folder written by Invoke-SemgrepScan.ps1 or
# Invoke-ZapScan.ps1. Returns the baseline IDs, the scan metadata and one row per format.
function Get-FormatResult([string]$Tool, [string]$Dir) {
    $ids  = @(Get-BaselineId $Tool $Dir)
    $meta = Get-Content -Raw (Join-Path $Dir 'scan.meta.json') | ConvertFrom-Json
    $rows = foreach ($f in Get-FormatCatalog | Where-Object Tool -eq $Tool) {
        $path   = Join-Path $Dir $f.File
        $exists = (Test-Path $path) -and (Get-Item $path).Length -gt 0
        $text   = if ($exists -and $f.Kind -eq 'text') { Get-Content -Raw $path } else { '' }
        $found  = if (-not $exists) { 'missing' }
                  elseif ($f.Kind -ne 'text') { 'open it' }
                  else {
                      $hits = @($ids | ForEach-Object { Test-IdPresent $text $_ } | Where-Object { $_ })
                      $note = if ($hits -contains 'short') { ' (short IDs)' } else { '' }
                      "$($hits.Count)/$($ids.Count)$note"
                  }
        [pscustomobject]@{
            Entry  = $f
            Path   = $path
            Text   = $text
            Found  = $found
            SizeKB = if ($exists) { [math]::Round((Get-Item $path).Length / 1KB, 1) } else { 0 }
            # HTML templates with images, CSS or JavaScript put them in a folder named after the file.
            Folder = $f.File -like '*.html' -and (Test-Path (Join-Path $Dir ([IO.Path]::GetFileNameWithoutExtension($f.File))) -PathType Container)
        }
    }
    [pscustomobject]@{ Ids = $ids; Meta = $meta; Rows = @($rows) }
}

# Returns 'full', 'short' (only the last part of a Semgrep rule ID, as the emacs format writes it:
# two rules with the same short name cannot be told apart) or $null.
function Test-IdPresent([string]$Text, [string]$Id) {
    $variants = @($Id, (ConvertTo-HtmlText $Id), ($Id -replace '"', '\"'), ($Id -replace '"', '&#34;'))
    foreach ($v in $variants) { if ($Text.IndexOf($v, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return 'full' } }
    if ($Id -match '\.([^.\s]+)$' -and $Text.Contains("($($Matches[1]))")) { return 'short' }
    $null
}
