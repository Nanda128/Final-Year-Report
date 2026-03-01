# Generic LaTeX build script for Final Year Report
# This script builds a LaTeX document and supports both interim and final reports
# Usage: .\build_report.ps1 <report_name>
# Example: .\build_report.ps1 interim
# Example: .\build_report.ps1 final

param(
    [Parameter(Mandatory=$true)]
    [string]$ReportName
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$reportDir = Join-Path $repoRoot $ReportName
$auxilDir = Join-Path $repoRoot 'auxil'
$logDir = Join-Path $repoRoot 'src/scripts/log' $ReportName
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
New-Item -ItemType Directory -Force -Path $auxilDir | Out-Null

$MainTexFile = "${ReportName}_report.tex"
$texSrc = Join-Path $reportDir $MainTexFile
$bibSrc = Join-Path $reportDir "${ReportName}_report.bib"
$bibDest = Join-Path $repoRoot "${ReportName}_report.bib"

# Set output path based on report name
if ($ReportName -eq 'interim') {
    $outputPath = Join-Path $repoRoot "Interim_FYP-DT-MSAR_23070854.pdf"
}
elseif ($ReportName -eq 'final') {
    $outputPath = Join-Path $repoRoot "Final_FYP-DT-MSAR_23070854.pdf"
}
else {
    $outputPath = Join-Path $repoRoot "${ReportName}_report.pdf"
}

Push-Location $repoRoot
try
{
    # Copy .tex and .bib from report directory to repo root
    Copy-Item $texSrc $MainTexFile -Force
    if (Test-Path $bibSrc) {
        Copy-Item $bibSrc $bibDest -Force
    }

    $sectionsSrc = Join-Path $reportDir 'sections'
    $sectionsDest = Join-Path $repoRoot 'sections'
    if (Test-Path $sectionsSrc) {
        if (Test-Path $sectionsDest) {
            Remove-Item -Recurse -Force $sectionsDest
        }
        Copy-Item -Recurse $sectionsSrc $sectionsDest
    }

    pdflatex -interaction=nonstopmode -halt-on-error "$MainTexFile" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'pdflatex-pass1.scripts.log')

    if (Test-Path "${ReportName}_report.aux")
    {
        bibtex "${ReportName}_report" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'bibtex.scripts.log')
    }

    pdflatex -interaction=nonstopmode -halt-on-error "$MainTexFile" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'pdflatex-pass2.scripts.log')
    pdflatex -interaction=nonstopmode -halt-on-error "$MainTexFile" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'pdflatex-pass3.scripts.log')

    $tempPdfPath = Join-Path $repoRoot "${ReportName}_report.pdf"
    if (Test-Path $tempPdfPath)
    {
        Move-Item $tempPdfPath $outputPath -Force
        foreach ($ext in @('aux', 'log', 'bbl', 'blg'))
        {
            $f = Join-Path $repoRoot "${ReportName}_report.$ext"
            if (Test-Path $f)
            {
                Move-Item $f $auxilDir -Force
            }
        }
        Get-ChildItem -Path $repoRoot -MaxDepth 1 -Include "*.out","*.toc","*.bbl","*.blg","*.brf" -File -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path (Join-Path $repoRoot 'sections') -Include "*.out","*.brf" -File -ErrorAction SilentlyContinue | Remove-Item -Force

        $pdfWordCount = $null
        $pdfPath = $outputPath
        $pdftotextCmd = Get-Command pdftotext -ErrorAction SilentlyContinue
        if ($pdftotextCmd)
        {
            try
            {
                $rawPdfText = & $pdftotextCmd.Source -layout -enc UTF-8 "$pdfPath" - 2> $null
                if ($rawPdfText -is [System.Array])
                {
                    $rawPdfText = $rawPdfText -join "`n"
                }
                $pdfTokens = ($rawPdfText -split '\s+') | Where-Object { $_ -ne '' }
                $pdfWordCount = $pdfTokens.Count
            }
            catch
            {
                $pdfWordCount = $null
            }
        }
        else
        {
            $pdfWordCount = $null
        }
        if ($null -ne $pdfWordCount)
        {
            $pdfText = "Word count (PDF text): $pdfWordCount/10,000"
            Write-Output $pdfText
        }
        else
        {
            Write-Output "Word count (PDF text): unavailable (pdftotext not available)/10,000"
        }
        Write-Output "Done. Output: $( Resolve-Path $outputPath ). Log files cleaned up. Build logs: $( Resolve-Path $logDir )"
    }
    else
    {
        Get-ChildItem -Path $repoRoot -MaxDepth 1 -Include "*.aux","*.log","*.out","*.toc","*.bbl","*.blg" -File -ErrorAction SilentlyContinue | Move-Item -Destination $logDir -Force
        Write-Output "PDF compilation failed. Logs: $( Resolve-Path $logDir )"
    }
}
finally
{
    Pop-Location
}

