# This script is for building a LaTeX document located in the project root directory.
# It runs pdflatex and bibtex as needed, captures logs, and organizes output files
# This script assumes that pdflatex and bibtex are installed and available in the system PATH.
# Also, don't worry about moving this script anywhere. It works out the box from this location.

# This script is for Windows users, if you are on Linux or macOS, please use the corresponding shell script in build_interim.sh.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$interimDir = Join-Path $repoRoot 'interim'
$auxilDir = Join-Path $repoRoot 'auxil'
$logDir = Join-Path $repoRoot 'src/scripts/log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
New-Item -ItemType Directory -Force -Path $auxilDir | Out-Null

$outputPath = Join-Path $repoRoot "Interim_FYP-DT-MSAR_23070854.pdf"
$MainTexFile = "interim_report.tex"
$texPath = Join-Path $interimDir $MainTexFile
$bibPathSrc = Join-Path $interimDir 'interim_report.bib'

Push-Location $interimDir
try
{
    pdflatex -interaction=nonstopmode -halt-on-error "$MainTexFile" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'pdflatex-pass1.scripts.log')

    if (Test-Path (Join-Path $interimDir 'interim_report.aux'))
    {
        bibtex interim_report 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'bibtex.scripts.log')
    }

    pdflatex -interaction=nonstopmode -halt-on-error "$MainTexFile" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'pdflatex-pass2.scripts.log')
    pdflatex -interaction=nonstopmode -halt-on-error "$MainTexFile" 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'pdflatex-pass3.scripts.log')

    $tempPdfPath = Join-Path $interimDir "interim_report.pdf"
    if (Test-Path $tempPdfPath)
    {
        Move-Item $tempPdfPath $outputPath -Force
        foreach ($ext in @('aux', 'log', 'bbl', 'blg'))
        {
            $f = Join-Path $interimDir "interim_report.$ext"
            if (Test-Path $f)
            {
                Move-Item $f $auxilDir -Force
            }
        }
        Get-ChildItem -Path $interimDir -Include "*.out","*.toc","*.bbl","*.blg" -File -ErrorAction SilentlyContinue | Remove-Item -Force

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
            $rawPdfText = Get-PdfTextUsingWinRT -PdfPath $pdfPath
            if ($rawPdfText)
            {
                $pdfTokens = ($rawPdfText -split '\s+') | Where-Object { $_ -ne '' }
                $pdfWordCount = $pdfTokens.Count
            }
            else
            {
                $pdfWordCount = $null
            }
        }
        if ($null -ne $pdfWordCount)
        {
            $pdfText = "Word count (PDF text): $pdfWordCount/10,000"
            Write-Output $pdfText
        }
        else
        {
            Write-Output "Word count (PDF text): unavailable (pdftotext/WinRT extractor not available)/10,000"
        }
        Write-Output "Done. Output: $( Resolve-Path $outputPath ). Log files cleaned up. Build logs: $( Resolve-Path $logDir )"
    }
    else
    {
        Get-ChildItem -Path $interimDir -Include "*.aux","*.log","*.out","*.toc","*.bbl","*.blg" -File -ErrorAction SilentlyContinue | Move-Item -Destination $logDir -Force
        Write-Output "PDF compilation failed. Logs: $( Resolve-Path $logDir )"
    }
}
finally
{
    Pop-Location
}
