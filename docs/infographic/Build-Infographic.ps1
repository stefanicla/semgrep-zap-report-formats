<#
.SYNOPSIS
    Prints infographic.html to "Semgrep and ZAP report formats.pdf" (A4 landscape, one page per <section class="page">) with headless Microsoft Edge.

.DESCRIPTION
    Prints the page with Edge (no header or footer) and checks the page count and size.
    -Preview also writes one PNG per page to %TEMP%\semgrep-zap-infographic for a quick look.
    Windows only (needs Microsoft Edge).

.EXAMPLE
    .\docs\infographic\Build-Infographic.ps1 -Preview
    Writes docs\infographic\out\Semgrep and ZAP report formats.pdf.
#>
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path $PSScriptRoot 'out'),
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
$edge = @(${env:ProgramFiles(x86)}, $env:ProgramFiles) | Where-Object { $_ } |
    ForEach-Object { Join-Path $_ 'Microsoft\Edge\Application\msedge.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge (msedge.exe) was not found under Program Files.' }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$work = Join-Path ([IO.Path]::GetTempPath()) 'semgrep-zap-infographic'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$html = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot 'infographic.html')
$built = Join-Path $work 'build.html'
[IO.File]::WriteAllText($built, $html, [Text.UTF8Encoding]::new($false))
$uri = ([Uri]$built).AbsoluteUri
$pageCount = ([regex]::Matches($html, '<section class="page')).Count
$edgeProfile = Join-Path $work 'edge-profile'

$pdf = Join-Path $OutDir 'Semgrep and ZAP report formats.pdf'
Remove-Item $pdf -ErrorAction SilentlyContinue
$p = Start-Process $edge -ArgumentList @('--headless=new', '--disable-gpu', "--user-data-dir=`"$edgeProfile`"", '--no-pdf-header-footer',
    "--print-to-pdf=`"$pdf`"", $uri) -Wait -PassThru -WindowStyle Hidden
if (-not (Test-Path $pdf)) { throw "The PDF was not written (Edge exit code $($p.ExitCode))." }

if ($Preview) {
    # 297 x 210 mm at 96 dpi = 1123 x 794 px per page.
    $png = Join-Path $work 'shot.png'
    Start-Process $edge -ArgumentList @('--headless=new', '--disable-gpu', "--user-data-dir=`"$edgeProfile`"", '--hide-scrollbars',
        "--window-size=1123,$(794 * $pageCount)", "--screenshot=`"$png`"", $uri) -Wait -WindowStyle Hidden
    Add-Type -AssemblyName System.Drawing
    $img = [Drawing.Bitmap]::new($png)
    for ($i = 0; $i -lt $pageCount; $i++) {
        $crop = $img.Clone([Drawing.Rectangle]::new(0, 794 * $i, 1123, [math]::Min(794, $img.Height - 794 * $i)), $img.PixelFormat)
        $crop.Save((Join-Path $work "page$($i + 1).png")); $crop.Dispose()
    }
    $img.Dispose()
    Write-Host "Preview: $work\page1..$pageCount.png"
}

$bytes = [IO.File]::ReadAllText($pdf, [Text.Encoding]::GetEncoding(28591))
$pages = ([regex]::Matches($bytes, '/Type\s*/Page[^s]')).Count
Write-Host "PDF: $pdf ($pages pages, $([math]::Round((Get-Item $pdf).Length / 1KB)) KB)"
$expected = ([regex]::Matches($html, '<section class="page')).Count
if ($pages -ne $expected) { Write-Warning "Expected $expected pages, got ${pages}: some content overflows a page." }
