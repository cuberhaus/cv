# Pol Casacuberta — CV

LaTeX sources for my CV, in both English and Spanish.

Built on the [Awesome-CV](https://github.com/posquit0/Awesome-CV) template
(CC BY-SA 4.0).

## Layout

```
.
├── awesome-cv.cls       # upstream template class
├── cv_english.tex       # English entry point
├── cv_spanish.tex       # Spanish entry point
├── cv/                  # shared section files (*_es.tex for Spanish)
│   ├── summary.tex / summary_es.tex
│   ├── education.tex / education_es.tex
│   ├── skills.tex / skills_es.tex
│   └── experience.tex / experience_es.tex
├── fonts/               # bundled fonts used by XeLaTeX
└── profile.jpeg         # header photo
```

## Build

Requires a TeX distribution with `xelatex` (TeX Live or MiKTeX).

```bash
make           # build both PDFs
make english   # cv_english.pdf only
make spanish   # cv_spanish.pdf only
make clean     # remove LaTeX aux files
```

Or directly:

```bash
xelatex cv_english.tex
xelatex cv_spanish.tex
```

## Editing

Content sections live in `cv/`. Edit the language-specific pair
(`experience.tex` + `experience_es.tex`, etc.) to keep both CVs in sync.
