# Semgrep and ZAP report formats

Which reports can the **free** versions of Semgrep and OWASP ZAP produce? What does each one contain,
and who is it for? Which one can go into a **Word document**? This page answers these questions with
measurements on one small demo app. It also shows how to check each format by hand.

| | Semgrep Community Edition | OWASP ZAP |
|---|---|---|
| Kind | **SAST**: reads the source code | **DAST**: attacks the running application |
| Version | 1.182.1, ruleset `p/owasp-top-ten` (559 free rules) | 2.17.0, Report Generation add-on 0.46.0 |
| Formats | 8 | 12 report templates |
| How | One `semgrep scan` writes every format at once | One scan, then one `report` job per template |
| Run time on the demo app | about 15 s | about 2.5 min |

Every format of a tool comes from **one scan**, so the formats are different views of the same findings.

## Contents

- [Quick start](#quick-start)
- [The demo app](#the-demo-app)
- [Semgrep formats at a glance](#semgrep-formats-at-a-glance)
- [ZAP formats at a glance](#zap-formats-at-a-glance)
- [Which format for whom](#which-format-for-whom)
- [Which format for a Word document](#which-format-for-a-word-document)
- [Checking each format by hand](#checking-each-format-by-hand)
- [Pitfalls](#pitfalls)
- [Not covered](#not-covered)

## Quick start

From the repository root, in PowerShell 7, with Docker Desktop running:

```powershell
.\scripts\Update-SemgrepRules.ps1            # once: download the OWASP Top Ten ruleset into rules\
.\scripts\Invoke-FormatShowcase.ps1 -Open    # both scans, every format, overview page in the browser
.\scripts\Export-Samples.ps1                 # copy one example of each format into samples\
```

The output is a self-contained folder, `reports\formats-<UTC>\`, with `semgrep\` and `zap\` subfolders
(`report.*`, `scan.log`, `scan.meta.json`) and an `index.html` overview. Use
`-Tool semgrep` or `-Tool zap` to rescan only one tool.

## The demo app

[`app/app.py`](../app/app.py) is a small Python/Flask app of about 70 lines with 6 flaws planted on
purpose. [`app/expected.txt`](../app/expected.txt) lists them and what each tool reports.

| Flaw | Semgrep | ZAP |
|---|---|---|
| Hard-coded database password | ✅ | — (not visible from outside) |
| Reflected XSS | ✅ | ✅ |
| SQL injection | ✅ | ✅ |
| Command injection | ✅ | ✅ |
| Session cookie without security flags | — (no rule in the ruleset) | ✅ |
| Debug mode on all interfaces | ✅ | ✅ (server version header) |
| Missing security headers (not planted) | — | ✅ |

**Semgrep: 13 findings from 10 rules. ZAP: 12 alert types** (5 High, 2 Medium, 4 Low,
1 Informational) **with 27 instances**. The two tools complement each other.

## Semgrep formats at a glance

"Found" counts how many of the 10 rules in the JSON report appear in the file. "Code" means the
vulnerable code line is in the file.

| Option | File | For | Found | CWE / OWASP | Code | Size | Word |
|---|---|---|---|---|---|---|---|
| `--text` (default) | `report.txt` | People at a console | 10/10 | No | Yes | 10 KB | Poor |
| `--json` | `report.json` | Automation, archiving | 10/10 | **Yes** | **No** ¹ | 20 KB | No |
| `--sarif` | `report.sarif` | GitHub code scanning, IDEs | 10/10 | Yes | Yes | **1 MB** ² | No |
| `--gitlab-sast` | `report.gitlab-sast.json` | GitLab security dashboard | 10/10 | No | No | 19 KB | No |
| `--gitlab-secrets` | `report.gitlab-secrets.json` | GitLab secret detection | 10/10 ³ | No | No | 19 KB | No |
| `--junit-xml` | `report.junit.xml` | CI test results | 10/10 | No | Yes | 8 KB | No |
| `--emacs` | `report.emacs.txt` | Editors, grep | 10/10 ⁴ | No | Yes | 5 KB | No |
| `--vim` | `report.vim.txt` | Editors, grep | 10/10 | No | No | 5 KB | No |

Each option also has an `--<format>-output=<file>` form. Several of them in one command write all the
formats from one scan, which is what [`Invoke-SemgrepScan.ps1`](../scripts/Invoke-SemgrepScan.ps1) does.

1. In the free version, `extra.lines` (the code) and `extra.fingerprint` read **"requires login"**.
   They are filled in only for users logged in to the Semgrep AppSec Platform.
2. SARIF embeds the full description of **all 560 rules** in the ruleset, not only the 10 that matched.
3. `gitlab-secrets` lists **every** finding as `secret_detection`, including SQL injection and XSS.
4. `emacs` uses only the short rule name: the Django and the Flask `raw-html-format` rules look the same.

## ZAP formats at a glance

"Found" counts how many of the 12 alert types in the JSON report appear in the file. "HTTP" means the
requests and responses are included. "Folder" means the HTML file needs the folder of the same name
next to it (styles, scripts, images).

| Template | File | For | Found | HTTP | Size | Word |
|---|---|---|---|---|---|---|
| `traditional-html` | `report.traditional.html` | People, Word documents | 12/12 | No | 99 KB | **Yes**: 18 pages, real tables |
| `traditional-html-plus` | `report.traditional-plus.html` + folder | Developers reproducing an issue | 12/12 | Yes | 221 KB | Poor: 35 pages |
| `traditional-json` | `report.traditional.json` | Automation, archiving | 12/12 | No | 50 KB | No |
| `traditional-json-plus` | `report.traditional-plus.json` | Automation that needs the traffic | 12/12 | Yes | 130 KB | No |
| `traditional-xml` | `report.traditional.xml` | Older tools (for example DefectDojo) | 12/12 | No | 57 KB | No |
| `traditional-xml-plus` | `report.traditional-plus.xml` | Older tools that need the traffic | 12/12 | Yes | 138 KB | No |
| `traditional-md` | `report.traditional.md` | Wikis, pull requests, tickets | 12/12 | No | 45 KB | Poor: raw Markdown |
| `traditional-pdf` | `report.pdf` | Sending to someone, archiving | 12/12 ¹ | No | 73 KB | No: 16 A4 pages, read-only |
| `modern` | `report.modern.html` + folder | People: interactive review | 12/12 | Yes | 257 KB | Poor: 54 pages |
| `risk-confidence-html` | `report.risk-confidence.html` + folder | Triage: risk × confidence | 12/12 | Partly | 126 KB | Poor: 36 pages |
| `high-level-report` | `report.high-level.html` + folder | Managers: summary | 12/12 | No | 34 KB | Poor: charts lost |
| `sarif-json` | `report.sarif.json` | GitHub code scanning, SARIF tools | 12/12 | No | 134 KB | No |

1. Checked by hand with `pdftotext`; the presence check does not read PDF files.

What this means:

- **All ZAP formats carry all alerts.** They differ in detail (with or without HTTP traffic), in
  layout and in who can read them.
- **Semgrep has no format for people** other than plain text. For a readable Semgrep report, use
  the JSON or SARIF in another tool (an IDE, GitHub, GitLab, DefectDojo).

## Which format for whom

| Need | Semgrep | ZAP |
|---|---|---|
| A document for a person or a customer | `text` (plain) | `traditional-html` (into Word) or `traditional-pdf` |
| A management summary | — | `high-level-report` (in a browser) |
| A developer fixing the issue | `sarif` in VS Code, or `text` | `traditional-html-plus` or `modern` |
| GitHub code scanning | `sarif` | `sarif-json` (alerts point to URLs, not code) |
| GitLab security dashboard | `gitlab-sast` | — (GitLab has its own DAST format) |
| A CI test report (Jenkins, Azure DevOps) | `junit-xml` | — |
| A wiki page or ticket | — | `traditional-md` |
| Archiving, automation, the system of record | `json` | `traditional-json` |

## Which format for a Word document

**ZAP: `traditional-html`.** Word opens the HTML file directly and turns it into real, editable
tables: 18 A4 pages and 15 tables for 12 alerts.

1. In Word: **File → Open** → `report.traditional.html`.
2. **File → Save As → Word Document (.docx)**.
3. Optional: delete the *Insights* table (scan statistics) to shorten it.

Measured with Word 365 (A4 portrait) on the other formats:

| Format | Pages | In Word |
|---|---|---|
| ZAP `traditional-html` | 18 | **Yes**: clean tables |
| ZAP `high-level-report` | 3 | Poor: the charts need JavaScript, which Word does not run |
| ZAP `traditional-html-plus` | 35 | Poor: long, raw HTTP traffic |
| ZAP `risk-confidence-html` | 36 | Poor: long |
| ZAP `modern` | 54 | Poor: long, includes HTTP traffic |
| ZAP `traditional-md` | 21 | Poor: Word shows the Markdown symbols (pipes, hashes) as text |
| ZAP `traditional-pdf` | 16 | No: attach it as it is |
| Semgrep `text` | 4 | Poor: plain text drawn with box characters; set it to Consolas |

**Semgrep has no native format for Word.** Paste `report.txt` and set it to Consolas 8 pt, or import
the JSON or SARIF into a tool that produces reports (for example DefectDojo).

## Checking each format by hand

Open [`samples/`](../samples/), or the newest `reports\formats-<UTC>\` folder.
These findings are easy to search for:

| Tool | Search for |
|---|---|
| Semgrep | `tainted-sql-string` (line 46), `detected-username-and-password-in-uri` (line 14) |
| ZAP | `SQL Injection`, `Cookie No HttpOnly Flag` |

### Semgrep

- **text**: open it in an editor with a monospace font. Each finding shows the rule ID, a message, a
  link (`sg.run/...`) and the code line. A summary is at the top.
- **json**: `results[]` has 13 entries, each with `check_id`, `path`, `start.line`,
  `extra.severity` and `extra.metadata.cwe` / `owasp`. `extra.lines` reads "requires login".
- **sarif**: install the *SARIF Viewer* extension in VS Code and open the file. `version` is `2.1.0`,
  and `runs[0].results` has 13 results. `runs[0].tool.driver.rules` has 560 rules.
- **gitlab-sast / gitlab-secrets**: `vulnerabilities[]` has 13 entries in both files, with
  `category` `sast` and `secret_detection` respectively. The schema version is `15.0.4`. In GitLab
  they go under `artifacts:reports:sast` and `artifacts:reports:secret_detection`.
- **junit-xml**: one `<testcase>` with a `<failure>` per finding (13). Its `name` is the rule ID and
  its `file`/`line` are the location.
- **emacs / vim**: 13 lines each, one per finding:
  `app/app.py:46:23:error(tainted-sql-string):...` (emacs) and `app/app.py:46:23:E:python.flask...:...` (vim).

### ZAP

- **traditional-html, modern, risk-confidence-html, high-level-report**: open them in a browser,
  with their folder next to them. The first three list every alert with its description, URLs,
  evidence and solution; `high-level-report` shows counts and charts.
- **traditional-json / -xml**: `site[0].alerts[]` (JSON) or `<alertitem>` (XML) has 12 alerts, each
  with `riskdesc`, `confidence`, `cweid`, `solution` and `instances` (URL, parameter, attack,
  evidence). The `-plus` files add `request-header`, `request-body`, `response-header` and
  `response-body` to each instance.
- **traditional-md**: preview it in VS Code (Ctrl+Shift+V) or paste it into a GitHub or GitLab page.
- **traditional-pdf**: open `report.pdf`. It has 16 pages: summary, insights, the alert list, then
  the detail of each alert.
- **sarif-json**: `runs[0].results` has 27 results, one per instance. The location is a URL such as
  `http://demo-app:5000/hello?name=...`, with the attack as the snippet and `startLine` 1.

## Pitfalls

- **ZAP's PDF job deletes the HTML file of the same name.** With `reportFile: report.traditional.pdf`,
  the `traditional-pdf` job silently removed `report.traditional.html`, which another job had written.
  The PDF is generated through a temporary HTML file with the same base name. Give the PDF a
  different name (here `report.pdf`).
- **Semgrep CE hides the code in JSON.** `extra.lines` and `fingerprint` read "requires login". Use
  SARIF, text or JUnit when the code line is needed.
- **`gitlab-secrets` is not a secrets filter.** It reports every finding as a secret. GitLab would
  show SQL injection under *Secret Detection*.
- **Semgrep's version check stalls offline scans.** With no network, scans waited 2 to 6 minutes
  for the version check. `SEMGREP_ENABLE_VERSION_CHECK=0` brings it back to about 15 s.
- **Semgrep prefixes rule IDs with the ruleset's folder.** With `--config rules/owasp-top-ten.yaml`,
  `python.flask...` becomes `rules.python.flask...`. Here the ruleset is mounted at `/` to avoid it.
- **ZAP's DOM-based XSS check is not stable.** It drives a headless browser and is limited to 1 minute
  per rule by the plan, so it appears in most runs but not all (11 or 12 alert types).
- **ZAP HTML reports need their folder.** `modern`, `risk-confidence-html`, `high-level-report` and
  `traditional-html-plus` load styles and scripts from a folder next to the file. Send the folder too,
  or use `traditional-html`, which is self-contained.
- **ZAP's active scan is a real attack.** Run it only against systems you own or are allowed to test.
  Here the target is a container on an internal Docker network with no published port.

## Not covered

- **Semgrep AppSec Platform** (`semgrep ci`, Pro rules, Pro engine, dashboard, PR comments): not free.
- **Semgrep `--dataflow-traces`**: adds the path of tainted data to text, JSON and SARIF. Not used here.
- **ZAP's packaged scans** (`zap-baseline.py`, `zap-full-scan.py`) write the same templates with
  `-r` (HTML), `-J` (JSON), `-x` (XML) and `-w` (Markdown). This lab uses the Automation Framework,
  which reaches all 12 templates.
- **ZAP API reports** (`/JSON/reports/action/generate/`): same templates, generated from a running ZAP.
- **Custom templates**: both tools can be extended (ZAP report templates, Semgrep via JSON processing).
