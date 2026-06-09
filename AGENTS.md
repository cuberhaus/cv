# cv

Multilingual LaTeX CV (English, Spanish, Catalan) for Pol Casacuberta, built on the [Awesome-CV](https://github.com/posquit0/Awesome-CV) template and released as PDFs by GitHub Actions. Consumed by polcasacubertagil.com.

## Architecture

- Per-language entry points at the root: `cv_english.tex`, `cv_spanish.tex`, `cv_catalan.tex`.
- Shared section files under `cv/` with language suffixes: base = English, `_es.tex` = Spanish, `_ca.tex` = Catalan (e.g. `experience.tex` / `experience_es.tex` / `experience_ca.tex`).
- Template class `awesome-cv.cls`, bundled `fonts/`, and `profile.jpeg` header photo.

## Build and Test

- `make all` builds all three PDFs into `dist/` via `scripts/build-local.ps1` (PowerShell, XeLaTeX).
- `make english` / `make spanish` / `make catalan` build one language; `make clean` / `make distclean` remove `build/` and `dist/`.
- `make check` builds all and fails if any CV overflows to 2+ pages — run this before pushing.
- CI: `.github/workflows/build.yml` matrix-builds all three languages with `xu-cheng/latex-action@v3` (`latexmk_use_xelatex: true`); on push to `main` it publishes a dated archive release (`v<YYYY.MM.DD>-<sha>`) and retags a rolling `latest` release with all three PDFs.

## Conventions

- Keep the three languages in parity: when editing a section, update all of `*.tex`, `*_es.tex`, and `*_ca.tex` together.
- One canonical source per language — do not duplicate sections across entry points.
- Each CV must fit on one page (enforced by `make check`).

## Pitfalls

- The `latest` GitHub Release is the live feed for polcasacubertagil.com — breaking `build.yml` breaks the downstream site.
- The `publish` job deletes and recreates the `latest` tag every push to `main`; preserve that step or the release page will pin to an old commit.
- Build is XeLaTeX-only (custom fonts in `fonts/`); plain `pdflatex` will not work.

See [README.md](README.md) for full setup.
