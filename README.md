# Pol Casacuberta - CV

LaTeX sources for my CV in English, Spanish, and Catalan.

Built on the [Awesome-CV](https://github.com/posquit0/Awesome-CV) template
(CC BY-SA 4.0).

## Layout

```text
.
├── awesome-cv.cls       # upstream template class, trimmed to what the CV uses
├── cv-common.tex        # shared Awesome-CV layout and personal details
├── cv_english.tex       # English entry point (language strings only)
├── cv_spanish.tex       # Spanish entry point
├── cv_catalan.tex       # Catalan entry point
├── sections-common.tex  # section order and toggles shared by both styles
├── ats-common.tex       # shared local-only ATS-first layout
├── ats_*.tex            # ATS entry points (language strings only)
├── cv/                  # shared sections: base, *_es.tex, *_ca.tex
│   ├── summary.tex / summary_es.tex / summary_ca.tex
│   ├── education.tex / education_es.tex / education_ca.tex
│   ├── skills.tex / skills_es.tex / skills_ca.tex
│   └── experience.tex / experience_es.tex / experience_ca.tex
├── data/
│   ├── career.yaml      # AI-tailoring factual inventory
│   └── README.md        # inventory schema and reviewed tailoring workflow
├── fonts/               # bundled fonts used by XeLaTeX
├── profile-deloitte.jpeg # default CV portrait
└── profile-legacy.jpeg  # retained prior portrait
```

## Build

Local builds use the same `texlive/texlive:latest` Docker image as the build
script. Start Docker Desktop first, then run:

```bash
make all       # standard, photo-enabled PDFs in all languages
make english   # standard, photo-enabled English CV
make spanish   # standard, photo-enabled Spanish CV
make catalan   # standard, photo-enabled Catalan CV
make curated   # 24 public assets, built in one container with 4 parallel jobs
make curated-language LANGUAGE=spanish
make curated-preset PRESET=complete
make ats       # three local-only ATS-first PDFs
make validate-career
```

Curated public filenames use `cv_<language>_<preset>_<photo-mode>.pdf`.
Presets are `standard`, `technical`, `complete`, and `concise`; photo modes are
`photo` and `no-photo`. The language-only files remain compatibility aliases
for each language's `standard_photo` PDF. The ATS-first style remains local/CI
only and is not released or shown in PersonalPortfolio.

Set `CURATED_JOBS` to tune bounded parallelism, for example
`make curated CURATED_JOBS=2`. Focused targets use the same single-container
builder and are intended for development; run the complete `make curated`
matrix before delivery.

CI uses three language-level jobs. Each starts one TeX container to build that
language's eight public PDFs and its unpublished ATS validation with two
bounded parallel compiles.

Page count is intentionally not enforced; multi-page CVs are valid.

`make test` runs the unit tests (career inventory, section parity across the
three languages, and the build script's options against a fake `docker`); CI
runs it in a `test` job that gates publishing.

## Editing

Content sections live in `cv/`. Edit all three language variants together
(`experience.tex`, `experience_es.tex`, and `experience_ca.tex`) to preserve
parity. The Awesome-CV layout is canonical; the ATS-first entry points reuse
the same section files and must not fork their content.

`data/career.yaml` is an English-first factual inventory for AI-assisted
tailoring. It is context for reviewed CV proposals, not an automatic generator
or replacement for the LaTeX sections. Its [authoring guide](data/README.md)
defines every field, validation rules, and a fact-constrained example tailoring
prompt. Run `make validate-career` after edits.

## Adding another visual style

Awesome-CV remains the canonical public style. The ATS-first files demonstrate
how to add an optional local/CI style without copying career content:

1. Add one shared style file, such as `newstyle-common.tex`, containing only
   layout and typography, and ending with `\input{sections-common}`.
2. Add English, Spanish, and Catalan entry points that define `\cvsfx` (the
   `cv/` file suffix) and any style-specific strings, then input the shared style.
3. Extend the `-Style` validation and source-name mapping in
   `scripts/build-local.sh`, then expose an explicit Make target.
4. Add CI compilation for all three languages. Keep the style out of release
   upload patterns and PersonalPortfolio unless a separate release-contract
   change explicitly makes it public.
5. Build all languages through Docker and inspect extracted text order as well
   as the rendered pages before delivery.

Do not fork section content for a visual style. Facts and translations continue
to belong to the existing `cv/*.tex` language files.
