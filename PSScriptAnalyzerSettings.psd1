@{
    # For local linting (CI runs the same command, see .github/workflows/lint.yml):
    #   Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # The scripts are interactive lab tools: progress and summaries are meant for the
        # console, not the pipeline, which carries the data objects (the scan scripts return the output folder).
        'PSAvoidUsingWriteHost'
    )
}
