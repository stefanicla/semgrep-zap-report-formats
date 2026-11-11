# Security policy

## This repository contains a deliberately vulnerable application

[`app/app.py`](app/app.py) is a small Flask app with **six flaws planted on purpose**: a hard-coded
credential, reflected XSS, SQL injection, command injection, a cookie without flags and debug mode
on all interfaces. It exists only as a scan target. The full list is in [`app/expected.txt`](app/expected.txt).

- **Never deploy it** or expose it on a network you do not control.
- The scripts run it read-only, with no Linux capabilities, on an `--internal` Docker network with
  **no published port**. Only the ZAP container can reach it.
- The credential `postgresql://shop_admin:Demo-Passw0rd@db.internal:5432/shop` is **fake**. It is
  flaw #1, and it also appears in the sample reports under [`samples/`](samples/). Secret scanners
  will flag it: this is expected. [`.github/secret_scanning.yml`](.github/secret_scanning.yml)
  excludes those paths from GitHub secret scanning.

Please do **not** report the planted flaws as vulnerabilities.

## Supported versions

Only the latest commit on `main` is maintained.

## Reporting a real vulnerability

If you find a genuine security problem in the scripts, the Docker setup or the ZAP plan, for example
a way for the demo app to escape its isolation, please report it privately through
[GitHub private vulnerability reporting](https://github.com/stefanicla/semgrep-zap-report-formats/security/advisories/new).
Do not open a public issue.

Please include the steps to reproduce, the affected file and your Docker and PowerShell versions.
You should receive an acknowledgement within a week.
