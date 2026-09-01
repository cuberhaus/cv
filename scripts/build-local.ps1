# Build CV PDFs locally using the same TeX Live Docker image CI uses.
# Aux files (.log, .aux, .xdv, ...) go to ./build/
# Final PDFs are copied to ./dist/ for easy access.
#
# Usage:
#   pwsh scripts/build-local.ps1                                      # standard photo CVs in all languages
#   pwsh scripts/build-local.ps1 english -Preset technical -PhotoMode no-photo
#   pwsh scripts/build-local.ps1 -AllCurated -Parallelism 4           # 24 public release assets
#   pwsh scripts/build-local.ps1 spanish -AllCurated -OnlyPreset complete
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

    [switch]$AllCurated,

    [ValidateSet('standard', 'technical', 'complete', 'concise')]
    [string]$OnlyPreset,

    [ValidateRange(1, 16)]
    [int]$Parallelism = 4
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

    foreach ($d in @($buildDir, $distDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
    }

    $presets = if ($OnlyPreset) {
        @($OnlyPreset)
    } else {
        @('standard', 'technical', 'complete', 'concise')
    }
    $jobs = foreach ($t in $targets) {
        foreach ($presetName in $presets) {
            foreach ($photoName in @('photo', 'no-photo')) {
                $photoFlag = if ($photoName -eq 'photo') { '1' } else { '0' }
                "$t`t$presetName`t$photoName`t$($presetBits[$presetName])`t$photoFlag"
            }
        }
    }

    $dockerScript = @'
set -euo pipefail
parallelism="$1"

build_variant() {
    source_stem="$1"
    preset="$2"
    photo_mode="$3"
    bits="$4"
    photo_flag="$5"
    variant_stem="${source_stem}_${preset}_${photo_mode}"
    flags="\\def\\inccertifications{${bits:0:1}}\\def\\incextracurricular{${bits:1:1}}\\def\\incprojects{${bits:2:1}}\\def\\incskills{${bits:3:1}}\\def\\incphoto{${photo_flag}}"
    driver="build/${variant_stem}.tex"

    echo "=== Building ${variant_stem}.pdf ==="
    printf '%s\n' "\\def\\buildflagsprovided{1}${flags}\\input{${source_stem}.tex}" > "${driver}"
    latexmk -xelatex -interaction=nonstopmode -halt-on-error \
        -output-directory=build \
        -jobname="${variant_stem}" \
        "${driver}"
    rm -f "${driver}"
}
export -f build_variant

rm -f build/flags.tex
printf '%s\n' __CURATED_JOB_ARGUMENTS__ | xargs -r -P "${parallelism}" -n 5 bash -c 'build_variant "$@"' _
'@
    $jobArguments = ($jobs | ForEach-Object { "'$($_.Replace("'", "'\''"))'" }) -join ' '
    $dockerScript = $dockerScript.Replace('__CURATED_JOB_ARGUMENTS__', $jobArguments)

    Write-Host "Using image: $image" -ForegroundColor Cyan
    Write-Host "Building $($jobs.Count) curated variants in one container ($Parallelism parallel jobs)." -ForegroundColor Cyan
    $dockerScript | docker run --rm -i `
        -v "${repoRoot}:/workdir" `
        -w /workdir `
        $image `
        bash -s -- $Parallelism
    if ($LASTEXITCODE -ne 0) {
        throw 'Curated build failed.'
    }

    foreach ($job in $jobs) {
        $jobFields = $job -split "`t"
        $t = $jobFields[0]
        $presetName = $jobFields[1]
        $photoName = $jobFields[2]
        $variantStem = "${t}_${presetName}_${photoName}"
        $srcPdf = Join-Path $buildDir "$variantStem.pdf"
        $dstPdf = Join-Path $distDir "$variantStem.pdf"
        Copy-Item -Path $srcPdf -Destination $dstPdf -Force
        Write-Host "  -> $dstPdf" -ForegroundColor DarkGray

        if ($presetName -eq 'standard' -and $photoName -eq 'photo') {
            $aliasPdf = Join-Path $distDir "$t.pdf"
            Copy-Item -Path $srcPdf -Destination $aliasPdf -Force
            Write-Host "  -> $aliasPdf (back-compat alias)" -ForegroundColor DarkGray
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
