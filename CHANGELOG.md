# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-11

### Added

- Format showcase: one Semgrep CE 1.182.1 scan writing all 8 output formats, and one OWASP ZAP 2.17.0
  scan writing all 12 report templates, with an `index.html` overview per run.
- Deliberately vulnerable Flask demo app with 6 planted flaws and a known answer (`app/expected.txt`).
- Sample reports (`samples/`), detailed results (`docs/report-formats.md`) and a 4-page infographic source.
- Docker images pinned by digest. Semgrep runs offline, and the demo app is isolated on an internal network.
- Open-source files: MIT licence, security policy, contributing guide, code of conduct, PowerShell lint
  workflow, Dependabot, and issue and pull request templates.

[Unreleased]: https://github.com/stefanicla/semgrep-zap-report-formats/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/stefanicla/semgrep-zap-report-formats/releases/tag/v1.0.0
