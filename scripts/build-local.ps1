# Build CV PDFs locally using the same TeX Live Docker image CI uses.
# Aux files (.log, .aux, .xdv, ...) go to ./build/
# Final PDFs are copied to ./dist/ for easy access.
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
$buildDir = Join-Path $repoRoot 'build'
$distDir  = Join-Path $repoRoot 'dist'

$targets = switch ($Target) {
    'english' { @('cv_english') }
    'spanish' { @('cv_spanish') }
    'catalan' { @('cv_catalan') }
    default   { @('cv_english', 'cv_spanish', 'cv_catalan') }
}

foreach ($d in @($buildDir, $distDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

Write-Host "Using image: $image" -ForegroundColor Cyan
Write-Host "Aux dir:     $buildDir" -ForegroundColor Cyan
Write-Host "PDF dir:     $distDir" -ForegroundColor Cyan

foreach ($t in $targets) {
    Write-Host "`n=== Building $t.pdf ===" -ForegroundColor Yellow
    docker run --rm `
        -v "${repoRoot}:/workdir" `
        -w /workdir `
        $image `
        latexmk -xelatex -interaction=nonstopmode -halt-on-error `
                -output-directory=build "$t.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $t"
    }

    $srcPdf = Join-Path $buildDir "$t.pdf"
    $dstPdf = Join-Path $distDir  "$t.pdf"
    Copy-Item -Path $srcPdf -Destination $dstPdf -Force
    Write-Host "  -> $dstPdf" -ForegroundColor DarkGray
}

# Page-count check (parses the xelatex log written during the build)
if ($Check) {
    $overflow = @()
    foreach ($t in $targets) {
        $log = Join-Path $buildDir "$t.log"
        if (-not (Test-Path $log)) {
            Write-Host ("  ? {0}: no log file" -f $t) -ForegroundColor DarkYellow
            continue
        }
        $match = Select-String -Path $log -Pattern 'Output written on .*\((\d+) pages?' |
            Select-Object -Last 1
        if (-not $match) {
            Write-Host ("  ? {0}: page count not found in log" -f $t) -ForegroundColor DarkYellow
            continue
        }
        $pages = [int]$match.Matches[0].Groups[1].Value
        $mark = if ($pages -gt 1) { 'X' } else { 'OK' }
        $color = if ($pages -gt 1) { 'Red' } else { 'Green' }
        Write-Host ("  [{0}] {1}: {2} page(s)" -f $mark, $t, $pages) -ForegroundColor $color
        if ($pages -gt 1) { $overflow += $t }
    }
    if ($overflow.Count -gt 0) {
        Write-Host "`nOverflow detected: $($overflow -join ', ')" -ForegroundColor Red
        exit 1
    }
    Write-Host "`nAll CVs fit on one page." -ForegroundColor Green
}
