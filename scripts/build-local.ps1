# Build CV PDFs locally using the same TeX Live Docker image CI uses.
#
# Usage:
#   pwsh scripts/build-local.ps1             # build all 3
#   pwsh scripts/build-local.ps1 english     # build one
#   pwsh scripts/build-local.ps1 -Check      # build all + fail if any > 1 page

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('all', 'english', 'spanish', 'catalan')]
    [string]$Target = 'all',

    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$image = 'texlive/texlive:latest'

$targets = switch ($Target) {
    'english' { @('cv_english') }
    'spanish' { @('cv_spanish') }
    'catalan' { @('cv_catalan') }
    default   { @('cv_english', 'cv_spanish', 'cv_catalan') }
}

Write-Host "Using image: $image" -ForegroundColor Cyan

foreach ($t in $targets) {
    Write-Host "`n=== Building $t.pdf ===" -ForegroundColor Yellow
    docker run --rm `
        -v "${repoRoot}:/workdir" `
        -w /workdir `
        $image `
        latexmk -xelatex -interaction=nonstopmode -halt-on-error "$t.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $t"
    }
}

# Page-count check (uses pdfinfo if available, else Python)
if ($Check) {
    $overflow = @()
    foreach ($t in $targets) {
        $pdf = Join-Path $repoRoot "$t.pdf"
        if (-not (Test-Path $pdf)) { continue }

        $pages = docker run --rm -v "${repoRoot}:/workdir" -w /workdir $image `
            pdfinfo "$t.pdf" 2>$null | Select-String -Pattern '^Pages:' | ForEach-Object {
                ($_ -replace '\D', '')
            }
        $pages = [int]$pages
        $mark = if ($pages -gt 1) { "✗" } else { "✓" }
        Write-Host ("  {0} {1}: {2} page(s)" -f $mark, $t, $pages)
        if ($pages -gt 1) { $overflow += $t }
    }
    if ($overflow.Count -gt 0) {
        Write-Host "`nOverflow detected: $($overflow -join ', ')" -ForegroundColor Red
        exit 1
    }
    Write-Host "`nAll CVs fit on one page." -ForegroundColor Green
}
