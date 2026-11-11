SEMGREP AND OWASP ZAP REPORT FORMATS - SAMPLES
==============================================

One example of every report format that the free versions of two security scanners can produce:
  - Semgrep Community Edition 1.182.1 with the free "OWASP Top Ten" ruleset (SAST: reads the source code)
  - OWASP ZAP 2.17.0 (DAST: attacks the running application)

Both scanned the same small demo web app (app/app.py, about 70 lines of Python/Flask) with 6 flaws planted on
purpose. app/expected.txt lists them and what each tool reports. Each tool scanned ONCE; every format
below is a different view of that one scan.
  - Semgrep: 13 findings from 10 rules.
  - ZAP:     12 alert types (5 High, 2 Medium, 4 Low, 1 Informational).

FOUND = how many of the rules (Semgrep) or alert types (ZAP) in the JSON report appear in the file.


SEMGREP  (one scan, all formats at once: semgrep scan --json-output=... --sarif-output=... ...)
-------
FILE                        FORMAT          FOR                                   OPEN WITH                      IN WORD  FOUND
--------------------------  --------------  ------------------------------------  -----------------------------  -------  -----------------
report.txt                  text            People at a console                   Text editor                    Poor     10/10
report.json                 json            Automation, archiving (the baseline)  VS Code, any editor            No       10/10
report.sarif                sarif           GitHub code scanning, IDEs            VS Code (SARIF Viewer)         No       10/10
report.gitlab-sast.json     gitlab-sast     GitLab security dashboard (SAST)      GitLab, any editor             No       10/10
report.gitlab-secrets.json  gitlab-secrets  GitLab secret detection               GitLab, any editor             No       10/10
report.junit.xml            junit-xml       CI test results                       Jenkins, Azure DevOps, GitLab  No       10/10
report.emacs.txt            emacs           Editors, grep                         Emacs, any editor              No       10/10 (short IDs)
report.vim.txt              vim             Editors, grep                         Vim quickfix, any editor       No       10/10

OWASP ZAP  (one scan, then one "report" job per template; see config/zap-plan.yaml)
---------
FILE                                     FORMAT                 FOR                                     OPEN WITH                        IN WORD  FOUND
---------------------------------------  ---------------------  --------------------------------------  -------------------------------  -------  -------
report.traditional.html                  traditional-html       People, Word documents                  Browser or Word                  YES      12/12
report.traditional-plus.html (+ folder)  traditional-html-plus  Developers reproducing an issue         Browser                          Poor     12/12
report.traditional.json                  traditional-json       Automation, archiving (the baseline)    VS Code, any editor              No       12/12
report.traditional-plus.json             traditional-json-plus  Automation that needs the HTTP traffic  VS Code, any editor              No       12/12
report.traditional.xml                   traditional-xml        Older tools that read ZAP XML           Any editor                       No       12/12
report.traditional-plus.xml              traditional-xml-plus   Older tools that need the HTTP traffic  Any editor                       No       12/12
report.traditional.md                    traditional-md         Wikis, pull requests, tickets           GitHub, GitLab, VS Code preview  Poor     12/12
report.pdf                               traditional-pdf        Sending to someone, archiving           PDF reader                       No       open it
report.modern.html (+ folder)            modern                 People: interactive review              Browser                          Poor     12/12
report.risk-confidence.html (+ folder)   risk-confidence-html   Triage: risk x confidence matrix        Browser                          Poor     12/12
report.high-level.html (+ folder)        high-level-report      Managers: one-page summary              Browser                          Poor     12/12
report.sarif.json                        sarif-json             GitHub code scanning, SARIF tools       VS Code (SARIF Viewer)           No       12/12

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


Source: formats-20261106T073849Z (scripts/Invoke-FormatShowcase.ps1). Exported by scripts/Export-Samples.ps1.
