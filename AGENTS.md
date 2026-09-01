# cv

Multilingual LaTeX CV (English, Spanish, Catalan) for Pol Casacuberta, built on the [Awesome-CV](https://github.com/posquit0/Awesome-CV) template and released as PDFs by GitHub Actions. Consumed by polcasacubertagil.com.

## Architecture

- Per-language entry points at the root: `cv_english.tex`, `cv_spanish.tex`, `cv_catalan.tex`.
- Shared section files under `cv/` with language suffixes: base = English, `_es.tex` = Spanish, `_ca.tex` = Catalan (e.g. `experience.tex` / `experience_es.tex` / `experience_ca.tex`).
- Template class `awesome-cv.cls`, bundled `fonts/`, `profile-deloitte.jpeg` default portrait, and retained `profile-legacy.jpeg` portrait.
- **Curated presets** select the existing four optional sections (`certifications`, `extracurricular`, `projects`, `skills`); summary, education, and experience are always on. `standard` = `0111`, `technical` = `0011`, `complete` = `1111`, and `concise` = `0001` in `c/e/p/s` order. Entry points read overrides from `build/flags.tex` and conditionally include the portrait with `\incphoto`.
- `ats_english.tex`, `ats_spanish.tex`, and `ats_catalan.tex` provide a local/CI-only ATS-first style using the same localized section files; do not publish it or expose it in PersonalPortfolio.
- `data/career.yaml` is the public English-first factual inventory for AI-assisted tailoring. Its schema and reviewed tailoring workflow are documented in `data/README.md`. Validate with `make validate-career`; it does not automatically update LaTeX content.

## Build and Test

- `make all` builds all three standard photo PDFs into `dist/` via `scripts/build-local.ps1` (PowerShell, XeLaTeX, Docker); `make curated` builds 24 public assets and `make ats` builds local-only ATS PDFs.
- `make english` / `make spanish` / `make catalan` build one language; `make clean` / `make distclean` remove `build/` and `dist/`.
- `make check` builds the standard photo CVs and performs no page-count enforcement; valid CVs may be multi-page.
- **Variants**: `pwsh scripts/build-local.ps1 english -Preset technical -PhotoMode no-photo`; `-AllCurated` builds every public preset/photo asset. The script writes `build/flags.tex` then runs Dockerized latexmk with descriptive filenames.
- CI matrix-builds **24 public variants** (3 languages x 4 presets x 2 photo modes) and validates the three local-only ATS PDFs. On push to `main` it publishes a dated archive release and retags `latest` with **27 PDFs** (24 assets plus 3 `cv_<lang>.pdf` aliases for `standard_photo`).

## Conventions

- Keep the three languages in parity: when editing a section, update all of `*.tex`, `*_es.tex`, and `*_ca.tex` together.
- One canonical source per language - do not duplicate sections across entry points.
- Page count is intentionally not enforced; ensure multi-page output has deliberate breaks and does not clip or overlap.
- When adding a new toggleable section: scaffold `cv/<name>.tex` + `_es.tex` + `_ca.tex` (template: `\cvsection{...}` and an empty `\begin{cvhonors}\end{cvhonors}`), add a `\providecommand{\inc<name>}{0}` to all three top-level `.tex` files, add `\ifnum\inc<name>=1 \input{cv/<name>...}\fi` at the right position, extend `scripts/build-local.ps1`'s toggle string to N+1 chars, and expand the workflow matrix to `2^N x 3` jobs. Update PersonalPortfolio's checkbox UI in lockstep.

## Pitfalls

- Always build and validate LaTeX through the Docker-backed `scripts/build-local.ps1` targets or GitHub Actions. Do not run host-installed TeX binaries or install host TeX packages as a fallback.
- The `latest` GitHub Release is the live feed for polcasacubertagil.com - breaking `build.yml` breaks the downstream site.
- The `publish` job deletes and recreates the `latest` tag every push to `main`; preserve that step or the release page will pin to an old commit.
- Build is XeLaTeX-only (custom fonts in `fonts/`); plain `pdflatex` will not work.
- The 24-variant public matrix plus three ATS checks takes several minutes with default GitHub concurrency. Each job has a TeX Live cold-start; do not add per-job heavy setup steps without considering the multiplier.
- `cv_<lang>.pdf` (no preset/photo suffix) is a back-compat alias for `cv_<lang>_standard_photo.pdf`. PersonalPortfolio's `deploy.yml` fetches these assets, so update the downstream consumer in lockstep with release changes.
- The `cv/certifications*.tex` section files are sourced from `PersonalPortfolio/src/data/certifications.json` (single source of truth) and sorted newest-first. When adding or updating a certification, edit the JSON in PersonalPortfolio first, then mirror the change here (issuer names stay English; only dates are localised).

See [README.md](README.md) for full setup.
