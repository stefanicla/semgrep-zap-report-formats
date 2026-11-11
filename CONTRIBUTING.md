# Contributing

Thank you for your interest. This is a small proof of concept, so issues and focused pull requests
are welcome: a new report format, a newer tool version, a fix to a script or a correction to the docs.

## Getting started

1. Install the [prerequisites](README.md#prerequisites): PowerShell 7.4+ and Docker.
2. Download the Semgrep ruleset, which is not committed for licensing reasons:
   ```powershell
   .\scripts\Update-SemgrepRules.ps1
   ```
3. Run the showcase:
   ```powershell
   .\scripts\Invoke-FormatShowcase.ps1 -Open
   ```

## Before you open a pull request

- **Lint the PowerShell.** CI runs the same command:
  ```powershell
  Install-Module PSScriptAnalyzer -Scope CurrentUser   # once
  Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
  ```
- **Upgrading a tool?** Change the image digest in [`scripts/lib/Common.ps1`](scripts/lib/Common.ps1)
  (pin by `sha256`, never by tag alone). Then rerun the showcase, refresh `samples/` with
  `.\scripts\Export-Samples.ps1`, and update the versions in the README badges, the README tables,
  [`docs/report-formats.md`](docs/report-formats.md) and [`app/expected.txt`](app/expected.txt).
- **Do not commit** `reports/` or `rules/*.yaml`. Both are gitignored.
- **Do not "fix" the demo app.** Its flaws are the test fixture (see [SECURITY.md](SECURITY.md)).
- Keep the scripts Windows- and Linux-compatible (PowerShell 7, `Join-Path`, no Windows-only cmdlets),
  except the infographic build, which needs Microsoft Edge.
- Write docs in British English, in short, plain sentences.
- Add a line to [CHANGELOG.md](CHANGELOG.md) under `Unreleased`.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
