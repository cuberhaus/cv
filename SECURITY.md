# Security Policy — cv

## Reporting a Vulnerability

If you discover a security issue, please email polcg10@gmail.com. Do not open a public issue.

## Scope

This repository contains LaTeX sources for a multilingual CV (English, Spanish, Catalan). The build pipeline (GitHub Actions, [.github/workflows/build.yml](.github/workflows/build.yml)) produces PDFs that are released as build artifacts and consumed by [polcasacubertagil.com](https://polcasacubertagil.com).

### Build output

- Published PDFs contain only the CV content authored in the `.tex` sources.
- No secrets, API keys, or credentials should ever land in the build output. If you spot one, treat it as the vulnerability and report it.

### GitHub Actions

- The workflow uses pinned third-party actions. Dependabot ([.github/dependabot.yml](.github/dependabot.yml)) keeps these current with weekly PRs.
- Do not enable any workflow trigger that runs third-party code from forks against this account's secrets (no `pull_request_target` with checkout of fork code).

### Local builds

- The `make` targets invoke `scripts/build-local.ps1`, which runs `latexmk` against local sources only. No network access required at build time.
