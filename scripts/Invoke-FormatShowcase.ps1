<#
.SYNOPSIS
    Produces every report format of Semgrep (SAST) and OWASP ZAP (DAST) from one scan each, with an overview page.

.DESCRIPTION
    1. Runs Invoke-SemgrepScan.ps1 and Invoke-ZapScan.ps1 against the demo app, writing into
       reports/formats-<UTC>/semgrep and reports/formats-<UTC>/zap. With -Tool, only that tool
       is scanned and the other one is copied from the newest earlier showcase, if any.
    2. Presence check per format: how many of the baseline identifiers (Semgrep rule IDs from
       report.json, ZAP alert names from report.traditional.json) appear in the file. It shows
       what a format carries or drops; open the files to confirm.
    3. Writes reports/formats-<UTC>/index.html: the scan commands, an overview table per tool,
       then one section per format with a description, a link and its first 30 lines.

    The folder is self-contained and can be zipped and shared.
    Exit code 1 if a format file is missing or empty, 0 otherwise.

.EXAMPLE
    .\scripts\Invoke-FormatShowcase.ps1 -Open

.EXAMPLE
    .\scripts\Invoke-FormatShowcase.ps1 -Tool semgrep
    Rescans with Semgrep only (about 15 s); reuses the newest ZAP results.
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'semgrep', 'zap')]
    [string]$Tool = 'all',
    [switch]$Open
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\Common.ps1')

$previous = Get-NewestFolder 'formats-*'
$outDir = Join-Path $script:ReportsDir "formats-$(Get-UtcStamp)"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# --- 1. Scans -----------------------------------------------------------------------------
foreach ($t in 'semgrep', 'zap') {
    $dir = Join-Path $outDir $t
    if ($Tool -in 'all', $t) {
        $script = if ($t -eq 'semgrep') { 'Invoke-SemgrepScan.ps1' } else { 'Invoke-ZapScan.ps1' }
        & (Join-Path $PSScriptRoot $script) -OutDir $dir | Out-Null
    }
    elseif ($previous -and (Test-Path (Join-Path $previous.FullName $t))) {
        Write-Host "Reusing the $t results of $($previous.Name)"
        Copy-Item -Recurse (Join-Path $previous.FullName $t) $dir
    }
}

# --- 2. Presence check --------------------------------------------------------------------
$failures = 0
$toolRows = [ordered]@{}
foreach ($t in 'semgrep', 'zap') {
    $dir = Join-Path $outDir $t
    if (-not (Test-Path $dir)) { continue }
    $result = Get-FormatResult $t $dir
    $failures += @($result.Rows | Where-Object Found -eq 'missing').Count
    $toolRows[$t] = $result
}

# --- 3. index.html ------------------------------------------------------------------------
$toolTitle = @{ semgrep = 'Semgrep Community Edition (SAST)'; zap = 'OWASP ZAP (DAST)' }
$idLabel   = @{ semgrep = 'rules matched'; zap = 'alert types' }
$wordCell  = @{ yes = '<td class="ok">Yes</td>'; poor = '<td class="part">Poor</td>'; no = '<td class="na">No</td>' }
function Get-FoundCell([string]$Value) {
    if ($Value -notmatch '^(\d+)/(\d+)') { return "<td class=""num na"">$Value</td>" }
    $css = if ($Value -match 'short') { 'part' } elseif ($Matches[1] -eq $Matches[2]) { 'ok' } elseif ($Matches[1] -eq '0') { 'miss' } else { 'part' }
    "<td class=""num $css"">$Value</td>"
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<h1>Semgrep and ZAP report formats</h1>')
[void]$sb.AppendLine("<p class=""muted"">Generated $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC. One scan per tool of the same demo app (<code>app/</code>); every format comes from that one scan.</p>")
[void]$sb.AppendLine('<div class="banner"><b>Found</b> is a presence check: how many identifiers from the tool''s JSON report (Semgrep rule IDs, ZAP alert names) appear anywhere in the file. It shows what a format carries or drops; open the files to confirm. How to review each format by hand: <code>docs/report-formats.md</code>.</div>')

foreach ($t in $toolRows.Keys) {
    $info = $toolRows[$t]
    [void]$sb.AppendLine("<h2>$($toolTitle[$t]) $(ConvertTo-HtmlText $info.Meta.version)</h2>")
    [void]$sb.AppendLine("<p>Baseline: $($info.Ids.Count) $($idLabel[$t]). Scan took $($info.Meta.durationSec) s. Command inside the container:</p>")
    [void]$sb.AppendLine("<pre>$(ConvertTo-HtmlText $info.Meta.command)</pre>")
    [void]$sb.AppendLine('<div class="wrap"><table><thead><tr><th>Format</th><th>For</th><th>Open with</th><th>In Word</th><th class="num">Found</th><th class="num">KB</th><th>File</th></tr></thead><tbody>')
    foreach ($r in $info.Rows) {
        $file = "$t/$($r.Entry.File)"
        $folderNote = if ($r.Folder) { ' <span class="muted">+ folder</span>' } else { '' }
        [void]$sb.AppendLine("<tr><td class=""mono""><a href=""#$t-$($r.Entry.Name)"">$($r.Entry.Name)</a></td><td>$(ConvertTo-HtmlText $r.Entry.For)</td><td>$(ConvertTo-HtmlText $r.Entry.OpenWith)</td>$($wordCell[$r.Entry.Word])$(Get-FoundCell $r.Found)<td class=""num"">$($r.SizeKB)</td><td class=""mono""><a href=""$file"">$($r.Entry.File)</a>$folderNote</td></tr>")
    }
    [void]$sb.AppendLine('</tbody></table></div>')
}

foreach ($t in $toolRows.Keys) {
    foreach ($r in $toolRows[$t].Rows) {
        $file = "$t/$($r.Entry.File)"
        $how = if ($t -eq 'semgrep') { "Option: <code>$($r.Entry.Option)=&lt;file&gt;</code>" } else { "Report template: <code>$($r.Entry.Option)</code>" }
        [void]$sb.AppendLine("<h3 id=""$t-$($r.Entry.Name)"">$($t): $($r.Entry.Name)</h3>")
        [void]$sb.AppendLine("<p>$(ConvertTo-HtmlText $r.Entry.Description)</p><p>$how &middot; Found: $($r.Found) &middot; File: <a class=""mono"" href=""$file"">$file</a></p>")
        if ($r.Text) {
            $lines = @($r.Text -split "`r?`n" | Select-Object -First 30 | ForEach-Object { if ($_.Length -gt 200) { $_.Substring(0, 200) + ' ...' } else { $_ } })
            [void]$sb.AppendLine("<details><summary>First $($lines.Count) lines</summary><pre>$(ConvertTo-HtmlText ($lines -join "`n"))</pre></details>")
        }
    }
}
[void]$sb.AppendLine('<p class="muted">Generated by scripts/Invoke-FormatShowcase.ps1.</p>')

$css = @'
:root { --fg:#1f2328; --muted:#656d76; --bg:#ffffff; --line:#d0d7de; --code:#f6f8fa; --ok:#1a7f37; --part:#9a6700; --miss:#cf222e; --accent:#0969da; }
@media (prefers-color-scheme: dark) { :root { --fg:#e6edf3; --muted:#8d96a0; --bg:#0d1117; --line:#30363d; --code:#161b22; --ok:#3fb950; --part:#d29922; --miss:#f85149; --accent:#4493f8; } }
body { font: 15px/1.5 system-ui, sans-serif; color: var(--fg); background: var(--bg); max-width: 1200px; margin: 0 auto; padding: 16px; }
a { color: var(--accent); } h2 { margin-top: 2em; border-bottom: 1px solid var(--line); } h3 { margin-top: 1.6em; }
table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid var(--line); padding: 4px 8px; text-align: left; vertical-align: top; }
.wrap { overflow-x: auto; } .num { text-align: right; white-space: nowrap; } .mono, code, pre { font-family: Consolas, monospace; font-size: 13px; }
pre { background: var(--code); padding: 8px; overflow-x: auto; white-space: pre-wrap; word-break: break-all; }
.ok { color: var(--ok); font-weight: 600; } .part { color: var(--part); font-weight: 600; } .miss { color: var(--miss); font-weight: 600; } .na, .muted { color: var(--muted); }
.banner { border-left: 4px solid var(--accent); background: var(--code); padding: 8px 12px; }
'@
$index = Join-Path $outDir 'index.html'
"<!doctype html><html lang=""en""><head><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width, initial-scale=1""><title>Semgrep and ZAP report formats</title><style>$css</style></head><body>$($sb.ToString())</body></html>" |
    Set-Content -Encoding utf8 $index

# --- 4. Console summary -------------------------------------------------------------------
foreach ($t in $toolRows.Keys) {
    Write-Host "`n$($toolTitle[$t]): $($toolRows[$t].Ids.Count) $($idLabel[$t]) in the baseline"
    $toolRows[$t].Rows | Select-Object @{ n = 'Format'; e = { $_.Entry.Name } }, Found, SizeKB, @{ n = 'Word'; e = { $_.Entry.Word } }, @{ n = 'File'; e = { $_.Entry.File } } |
        Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}
Write-Host "Overview: $(Get-RepoRelativePath $index)"
if ($Open) { Invoke-Item $index }
if ($failures) { Write-Host "$failures format file(s) missing or empty."; exit 1 }
