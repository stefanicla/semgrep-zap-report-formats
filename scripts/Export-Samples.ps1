<#
.SYNOPSIS
    Copies one example of every report format into samples/, with a README.txt that explains them.

.DESCRIPTION
    Takes the newest reports/formats-<UTC> folder (or -From) and writes:
      samples/README.txt         what each file is, who it is for, how to open it, whether it fits in Word
      samples/semgrep/report.*   the 8 Semgrep formats
      samples/zap/report.*       the 12 ZAP formats (HTML templates keep their resource folder)
      samples/app/               the scanned demo app and its known answer (expected.txt)
    samples/ is replaced on every run. It is the input for the infographic and can be zipped and shared.

.EXAMPLE
    .\scripts\Export-Samples.ps1
#>
[CmdletBinding()]
param(
    # A reports/formats-<UTC> folder. Default: the newest one.
    [string]$From
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')

$source = if ($From) { Get-Item (Resolve-Path $From) } else { Get-NewestFolder 'formats-*' }
if (-not $source) { throw 'No reports\formats-* folder found. Run scripts\Invoke-FormatShowcase.ps1 first.' }
foreach ($t in 'semgrep', 'zap') {
    if (-not (Test-Path (Join-Path $source.FullName $t))) { throw "$($source.Name) has no $t results." }
}

$samples = Join-Path $script:RepoRoot 'samples'
if (Test-Path $samples) { Remove-Item -Recurse -Force (Join-Path $samples '*') }
New-Item -ItemType Directory -Force -Path $samples, (Join-Path $samples 'app') | Out-Null

foreach ($t in 'semgrep', 'zap') {
    $dst = Join-Path $samples $t
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    # Report files and their resource folders; not the scan log or metadata.
    Get-ChildItem (Join-Path $source.FullName $t) -Filter 'report*' | Copy-Item -Destination $dst -Recurse
}
Copy-Item (Join-Path $script:AppDir 'app.py'), (Join-Path $script:AppDir 'expected.txt') (Join-Path $samples 'app')

# --- README.txt -------------------------------------------------------------------------------
$results = [ordered]@{
    semgrep = Get-FormatResult 'semgrep' (Join-Path $source.FullName 'semgrep')
    zap     = Get-FormatResult 'zap' (Join-Path $source.FullName 'zap')
}
$wordText = @{ yes = 'YES'; poor = 'Poor'; no = 'No' }

function Format-SampleTable([object[]]$Rows) {
    $cols = 'FILE', 'FORMAT', 'FOR', 'OPEN WITH', 'IN WORD', 'FOUND'
    $data = @($Rows | ForEach-Object {
            $file = $_.Entry.File + $(if ($_.Folder) { ' (+ folder)' } else { '' })
            , @($file, $_.Entry.Name, $_.Entry.For, $_.Entry.OpenWith, $wordText[$_.Entry.Word], $_.Found)
        })
    $widths = for ($i = 0; $i -lt $cols.Count; $i++) {
        (@($cols[$i].Length) + @($data | ForEach-Object { $_[$i].Length }) | Measure-Object -Maximum).Maximum
    }
    $line = { param($cells) ((0..($cells.Count - 1) | ForEach-Object { $cells[$_].PadRight($widths[$_]) }) -join '  ').TrimEnd() }
    & $line $cols
    & $line @($widths | ForEach-Object { '-' * $_ })
    foreach ($d in $data) { & $line $d }
}

$s = $results.semgrep; $z = $results.zap
$semgrepFindings = @((Get-Content -Raw (Join-Path $source.FullName 'semgrep\report.json') | ConvertFrom-Json).results).Count
$zapAlerts = @((Get-Content -Raw (Join-Path $source.FullName 'zap\report.traditional.json') | ConvertFrom-Json).site | ForEach-Object { $_.alerts })
$zapByRisk = @('High', 'Medium', 'Low', 'Informational' | ForEach-Object {
        $risk = $_
        "$(@($zapAlerts | Where-Object { $_.riskdesc -like "$risk *" }).Count) $risk"
    }) -join ', '
$readme = @"
SEMGREP AND OWASP ZAP REPORT FORMATS - SAMPLES
==============================================

One example of every report format that the free versions of two security scanners can produce:
  - Semgrep Community Edition $($s.Meta.version) with the free "OWASP Top Ten" ruleset (SAST: reads the source code)
  - OWASP ZAP $($z.Meta.version) (DAST: attacks the running application)

Both scanned the same small demo web app (app/app.py, about 70 lines of Python/Flask) with 6 flaws planted on
purpose. app/expected.txt lists them and what each tool reports. Each tool scanned ONCE; every format
below is a different view of that one scan.
  - Semgrep: $semgrepFindings findings from $($s.Ids.Count) rules.
  - ZAP:     $($z.Ids.Count) alert types ($zapByRisk).

FOUND = how many of the rules (Semgrep) or alert types (ZAP) in the JSON report appear in the file.


SEMGREP  (one scan, all formats at once: semgrep scan --json-output=... --sarif-output=... ...)
-------
$((Format-SampleTable $s.Rows) -join "`n")

OWASP ZAP  (one scan, then one "report" job per template; see config/zap-plan.yaml)
---------
$((Format-SampleTable $z.Rows) -join "`n")

"(+ folder)": the HTML file needs the folder of the same name next to it (styles, scripts, images).


WHAT TO KNOW
  Semgrep
  - JSON is the complete format (CWE, OWASP category, confidence) - but in the free version the code
    line and the fingerprint read "requires login". The code snippet is in text, SARIF, JUnit and emacs.
  - SARIF is large (1 MB here) because it embeds the description of all 560 rules in the ruleset.
  - gitlab-secrets lists EVERY finding as a "secret", not only secrets. Use it only with a secrets ruleset.
  - gitlab-sast has no CWE and no code; emacs shows only the short rule name; vim has no code.
  - No native format is made for people: text is the only readable one (4 pages of plain text in Word).
  ZAP
  - traditional-html is the format for documents: it opens in Word as real tables (18 A4 pages here).
  - The PDF is ready to send (16 A4 pages) but cannot be edited.
  - The "-plus" variants and "modern" add the HTTP requests and responses: useful for developers,
    2-3 times longer (modern: 54 pages in Word).
  - high-level-report is the management summary, but its charts need JavaScript: lost in Word.
  - sarif-json works with GitHub code scanning, but DAST alerts point to URLs, not to code lines.
  Both
  - The tools complement each other: Semgrep finds the hard-coded password, ZAP finds the cookie
    flags and the missing security headers. Both find the injections.
  - Keep the JSON report as the system of record; the other formats are views of it.


ZAP HTML REPORT INTO WORD
  1. In Word: File > Open > zap/report.traditional.html
  2. File > Save As > Word Document (.docx)
  3. Optional: delete the "Insights" table (scan statistics) to shorten it.


Source: $($source.Name) (scripts/Invoke-FormatShowcase.ps1). Exported by scripts/Export-Samples.ps1.
"@
$readme | Set-Content -Encoding utf8 (Join-Path $samples 'README.txt')

Write-Host "Samples from $($source.Name) written to $(Get-RepoRelativePath $samples)"
