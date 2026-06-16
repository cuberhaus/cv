# cv

Multilingual LaTeX CV (English, Spanish, Catalan) for Pol Casacuberta, built on the [Awesome-CV](https://github.com/posquit0/Awesome-CV) template and released as PDFs by GitHub Actions. Consumed by polcasacubertagil.com.

## Architecture

- Per-language entry points at the root: `cv_english.tex`, `cv_spanish.tex`, `cv_catalan.tex`.
- Shared section files under `cv/` with language suffixes: base = English, `_es.tex` = Spanish, `_ca.tex` = Catalan (e.g. `experience.tex` / `experience_es.tex` / `experience_ca.tex`).
- Template class `awesome-cv.cls`, bundled `fonts/`, and `profile.jpeg` header photo.
- **Section toggles** (4 optional sections): `certifications`, `extracurricular`, `projects`, `skills`. Always-on: `summary`, `education`, `experience`. Top-level `.tex` files read overrides from `build/flags.tex` (via `\IfFileExists`) and fall back to `\providecommand` defaults (`0111` = canonical, no certifications). Toggle string convention: `cepsbits`, e.g. `1011` = certifications + projects + skills, no extracurricular.

## Build and Test

- `make all` builds all three canonical PDFs into `dist/` via `scripts/build-local.ps1` (PowerShell, XeLaTeX, Docker).
- `make english` / `make spanish` / `make catalan` build one language; `make clean` / `make distclean` remove `build/` and `dist/`.
- `make check` builds all and fails if the canonical `0111` variant overflows to 2+ pages - run this before pushing. Page-count is only enforced for `0111`; custom variants may legitimately exceed one page.
- **Custom variants**: `pwsh scripts/build-local.ps1 english -Toggles 1111` (all on), `-Toggles 0000` (minimum), etc. The script writes `build/flags.tex` then runs latexmk with `-jobname=cv_<lang>_<toggles>`, producing `dist/cv_<lang>_<toggles>.pdf`.
- CI: `.github/workflows/build.yml` matrix-builds **48 variants** (3 langs x 16 toggle combos) with `xu-cheng/latex-action@v3` (`pre_compile` writes `build/flags.tex`, `post_compile` renames the PDF). On push to `main` it publishes a dated archive release (`v<YYYY.MM.DD>-<sha>`) and retags a rolling `latest` release with **51 PDFs** (48 variants + 3 back-compat `cv_<lang>.pdf` aliases for the canonical 0111 build).

## Conventions

- Keep the three languages in parity: when editing a section, update all of `*.tex`, `*_es.tex`, and `*_ca.tex` together.
- One canonical source per language - do not duplicate sections across entry points.
- Canonical (`0111`) CV must fit on one page (enforced by `make check`). Custom variants may legitimately exceed one page; not enforced.
- When adding a new toggleable section: scaffold `cv/<name>.tex` + `_es.tex` + `_ca.tex` (template: `\cvsection{...}` and an empty `\begin{cvhonors}\end{cvhonors}`), add a `\providecommand{\inc<name>}{0}` to all three top-level `.tex` files, add `\ifnum\inc<name>=1 \input{cv/<name>...}\fi` at the right position, extend `scripts/build-local.ps1`'s toggle string to N+1 chars, and expand the workflow matrix to `2^N x 3` jobs. Update PersonalPortfolio's checkbox UI in lockstep.

## Pitfalls

- The `latest` GitHub Release is the live feed for polcasacubertagil.com - breaking `build.yml` breaks the downstream site.
- The `publish` job deletes and recreates the `latest` tag every push to `main`; preserve that step or the release page will pin to an old commit.
- Build is XeLaTeX-only (custom fonts in `fonts/`); plain `pdflatex` will not work.
- The 48-variant CI matrix takes ~3-5 min wall-clock with default GitHub concurrency. Each job has a TeX Live cold-start of ~10-15s; do not add per-job heavy setup steps without considering the multiplier.
- `cv_<lang>.pdf` (no toggle suffix) is a back-compat alias for `cv_<lang>_0111.pdf`. PersonalPortfolio's `deploy.yml` fetches the alias, so don't rename or drop it without updating the downstream consumer.
- The `cv/certifications*.tex` section files ship empty (templates only) - rendering `inccertifications=1` against the empty content shows just a header. Fill them in before promoting any `c=1` variant.

See [README.md](README.md) for full setup.
