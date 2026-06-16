# Build CV PDFs locally using the same TeX Live Docker image CI uses.
# Aux files (.log, .aux, .xdv, ...) go to ./build/
# Final PDFs are copied to ./dist/ for easy access.
#
# Usage:
#   pwsh scripts/build-local.ps1                       # build all 3 (canonical 0111 + cv_<lang>.pdf alias)
#   pwsh scripts/build-local.ps1 english               # build one (canonical)
#   pwsh scripts/build-local.ps1 -Check                # build all + fail if canonical variant > 1 page
#   pwsh scripts/build-local.ps1 -Toggles 1111         # all-on variant: cv_<lang>_1111.pdf
#   pwsh scripts/build-local.ps1 english -Toggles 0000 # minimum variant: cv_english_0000.pdf
#
# Toggle string positions (left-to-right): c, e, p, s
#   c = certifications, e = extracurricular, p = projects, s = skills
# '0111' (default) = skills+projects+extracurricular, no certifications -- matches the canonical CV.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('all', 'english', 'spanish', 'catalan')]
    [string]$Target = 'all',

    [ValidatePattern('^[01]{4}$')]
    [string]$Toggles = '0111',

    [switch]$Check,

    # When true, do not emit the back-compat cv_<lang>.pdf alias for the
    # canonical 0111 build. The matrix script sets this so 16 variants per
    # language do not all try to overwrite the same alias.
    [switch]$NoAlias
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

# Map the 4-bit toggle string to \def\inc*{0|1} overrides written to
# build/flags.tex (input'd by the top-level .tex files via \IfFileExists).
# Order matches the toggle string (left to right): c, e, p, s.
$bits = $Toggles.ToCharArray()

Write-Host "Using image: $image" -ForegroundColor Cyan
Write-Host "Aux dir:     $buildDir" -ForegroundColor Cyan
Write-Host "PDF dir:     $distDir" -ForegroundColor Cyan
Write-Host "Toggles:     $Toggles  (c=$($bits[0]) e=$($bits[1]) p=$($bits[2]) s=$($bits[3]))" -ForegroundColor Cyan

foreach ($t in $targets) {
    $variantStem = "${t}_$Toggles"
    Write-Host "`n=== Building $variantStem.pdf ===" -ForegroundColor Yellow

    # Use -jobname so latexmk writes <variantStem>.{aux,log,pdf} to keep
    # the matrix's per-variant aux files isolated from each other.
    docker run --rm `
        -v "${repoRoot}:/workdir" `
        -w /workdir `
        $image `
        bash -c "printf '\\def\\inccertifications{$($bits[0])}\\def\\incextracurricular{$($bits[1])}\\def\\incprojects{$($bits[2])}\\def\\incskills{$($bits[3])}\\n' > build/flags.tex && latexmk -xelatex -interaction=nonstopmode -halt-on-error -output-directory=build -jobname=$variantStem $t.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $variantStem"
    }

    $srcPdf = Join-Path $buildDir "$variantStem.pdf"
    $dstPdf = Join-Path $distDir  "$variantStem.pdf"
    Copy-Item -Path $srcPdf -Destination $dstPdf -Force
    Write-Host "  -> $dstPdf" -ForegroundColor DarkGray

    # Back-compat alias: cv_<lang>.pdf == cv_<lang>_0111.pdf (the canonical
    # build). Keeps existing release-asset URLs working for consumers (e.g.
    # PersonalPortfolio's deploy.yml which fetches `$BASE/cv_english.pdf`).
    if ($Toggles -eq '0111' -and -not $NoAlias) {
        $aliasPdf = Join-Path $distDir "$t.pdf"
        Copy-Item -Path $srcPdf -Destination $aliasPdf -Force
        Write-Host "  -> $aliasPdf (back-compat alias)" -ForegroundColor DarkGray
    }
}

# Page-count check (parses the xelatex log written during the build).
# Only enforced for the canonical 0111 variant -- custom variants are
# intentional user choices and may legitimately exceed 1 page.
if ($Check) {
    if ($Toggles -ne '0111') {
        Write-Host "`n-Check is only enforced for the canonical 0111 variant. Skipping for $Toggles." -ForegroundColor DarkYellow
        return
    }
    $overflow = @()
    foreach ($t in $targets) {
        $variantStem = "${t}_$Toggles"
        $log = Join-Path $buildDir "$variantStem.log"
        if (-not (Test-Path $log)) {
            Write-Host ("  ? {0}: no log file" -f $variantStem) -ForegroundColor DarkYellow
            continue
        }
        $match = Select-String -Path $log -Pattern 'Output written on .*\((\d+) pages?' |
            Select-Object -Last 1
        if (-not $match) {
            Write-Host ("  ? {0}: page count not found in log" -f $variantStem) -ForegroundColor DarkYellow
            continue
        }
        $pages = [int]$match.Matches[0].Groups[1].Value
        $mark = if ($pages -gt 1) { 'X' } else { 'OK' }
        $color = if ($pages -gt 1) { 'Red' } else { 'Green' }
        Write-Host ("  [{0}] {1}: {2} page(s)" -f $mark, $variantStem, $pages) -ForegroundColor $color
        if ($pages -gt 1) { $overflow += $variantStem }
    }
    if ($overflow.Count -gt 0) {
        Write-Host "`nOverflow detected: $($overflow -join ', ')" -ForegroundColor Red
        exit 1
    }
    Write-Host "`nCanonical 0111 build fits on one page in all languages." -ForegroundColor Green
}
