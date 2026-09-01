# Build CV PDFs locally using the same TeX Live Docker image CI uses.
# Aux files (.log, .aux, .xdv, ...) go to ./build/
# Final PDFs are copied to ./dist/ for easy access.
#
# Usage:
#   pwsh scripts/build-local.ps1                                      # standard photo CVs in all languages
#   pwsh scripts/build-local.ps1 english -Preset technical -PhotoMode no-photo
#   pwsh scripts/build-local.ps1 -AllCurated                          # 24 public release assets
#   pwsh scripts/build-local.ps1 catalan -Style ats -PhotoMode no-photo

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('all', 'english', 'spanish', 'catalan')]
    [string]$Target = 'all',

    [ValidateSet('standard', 'technical', 'complete', 'concise')]
    [string]$Preset = 'standard',

    [ValidateSet('photo', 'no-photo')]
    [string]$PhotoMode = 'photo',

    [ValidateSet('awesome', 'ats')]
    [string]$Style = 'awesome',

    [switch]$Check,

    [switch]$AllCurated
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$image = 'texlive/texlive:latest'
$buildDir = Join-Path $repoRoot 'build'
$distDir  = Join-Path $repoRoot 'dist'
$presetBits = @{
    standard = '0111'
    technical = '0011'
    complete = '1111'
    concise = '0001'
}

$targets = switch ($Target) {
    'english' { @('cv_english') }
    'spanish' { @('cv_spanish') }
    'catalan' { @('cv_catalan') }
    default   { @('cv_english', 'cv_spanish', 'cv_catalan') }
}

if ($AllCurated) {
    if ($Style -ne 'awesome') {
        throw '-AllCurated only builds public Awesome-CV release assets.'
    }
    foreach ($presetName in @('standard', 'technical', 'complete', 'concise')) {
        foreach ($photoName in @('photo', 'no-photo')) {
            & $PSCommandPath -Target $Target -Preset $presetName -PhotoMode $photoName
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }
    return
}

if ($Style -eq 'ats' -and $PhotoMode -ne 'no-photo') {
    throw 'The ATS style is intentionally photo-free; use -PhotoMode no-photo.'
}

foreach ($d in @($buildDir, $distDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

$bits = $presetBits[$Preset].ToCharArray()
$includePhoto = if ($PhotoMode -eq 'photo') { '1' } else { '0' }

Write-Host "Using image: $image" -ForegroundColor Cyan
Write-Host "Aux dir:     $buildDir" -ForegroundColor Cyan
Write-Host "PDF dir:     $distDir" -ForegroundColor Cyan
Write-Host "Style:       $Style" -ForegroundColor Cyan
Write-Host "Preset:      $Preset  (c=$($bits[0]) e=$($bits[1]) p=$($bits[2]) s=$($bits[3]))" -ForegroundColor Cyan
Write-Host "Photo mode:  $PhotoMode" -ForegroundColor Cyan

foreach ($t in $targets) {
    $sourceStem = if ($Style -eq 'awesome') { $t } else { $t -replace '^cv_', 'ats_' }
    $variantStem = if ($Style -eq 'awesome') { "${t}_${Preset}_${PhotoMode}" } else { "${sourceStem}_${Preset}" }
    Write-Host "`n=== Building $variantStem.pdf ===" -ForegroundColor Yellow

    # Use -jobname so latexmk writes <variantStem>.{aux,log,pdf} to keep
    # the matrix's per-variant aux files isolated from each other.
    docker run --rm `
        -v "${repoRoot}:/workdir" `
        -w /workdir `
        $image `
        bash -c "printf '\\def\\inccertifications{$($bits[0])}\\def\\incextracurricular{$($bits[1])}\\def\\incprojects{$($bits[2])}\\def\\incskills{$($bits[3])}\\def\\incphoto{$includePhoto}\n' > build/flags.tex && latexmk -xelatex -interaction=nonstopmode -halt-on-error -output-directory=build -jobname=$variantStem $sourceStem.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $variantStem"
    }

    $srcPdf = Join-Path $buildDir "$variantStem.pdf"
    $dstPdf = Join-Path $distDir  "$variantStem.pdf"
    Copy-Item -Path $srcPdf -Destination $dstPdf -Force
    Write-Host "  -> $dstPdf" -ForegroundColor DarkGray

    # Keep existing consumers on the photo-enabled standard asset.
    if ($Style -eq 'awesome' -and $Preset -eq 'standard' -and $PhotoMode -eq 'photo') {
        $aliasPdf = Join-Path $distDir "$t.pdf"
        Copy-Item -Path $srcPdf -Destination $aliasPdf -Force
        Write-Host "  -> $aliasPdf (back-compat alias)" -ForegroundColor DarkGray
    }
}

if ($Check) {
    Write-Host "`nCompilation completed successfully." -ForegroundColor Green
}
