SCRIPT ?= pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1
CURATED_JOBS ?= 4

ifeq ($(OS),Windows_NT)
  PYTHON ?= python
else
  PYTHON ?= python3
endif

.DEFAULT_GOAL := help

.PHONY: help all english spanish catalan \
        curated curated-language curated-preset ats \
        check validate-career test lint \
        hooks clean distclean

##@ General

help: ## Show this help message
	@awk ' \
		/^##@/      { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_-]+:.*##/ { \
			split($$0, parts, ":.*## *"); \
			printf "  \033[36m%-22s\033[0m %s\n", parts[1], parts[2] \
		} \
	' $(MAKEFILE_LIST)
	@echo ""
	@echo "Public presets: standard, technical, complete, concise. Photo modes: photo, no-photo."
	@echo "  pwsh scripts/build-local.ps1 english -Preset technical -PhotoMode no-photo"
	@echo "  pwsh scripts/build-local.ps1 catalan -Style ats -PhotoMode no-photo"

##@ Build

all: ## Build standard photo CVs in all languages -> dist/
	$(SCRIPT)

english: ## Build standard photo English CV -> dist/
	$(SCRIPT) english

spanish: ## Build standard photo Spanish CV -> dist/
	$(SCRIPT) spanish

catalan: ## Build standard photo Catalan CV -> dist/
	$(SCRIPT) catalan

##@ Variants & Presets

curated: ## Build all public variants in one container -> dist/
	$(SCRIPT) -AllCurated -Parallelism $(CURATED_JOBS)

curated-language: ## Build one language's public variants (use LANGUAGE=spanish)
	$(SCRIPT) $(LANGUAGE) -AllCurated -Parallelism $(CURATED_JOBS)

curated-preset: ## Build one preset in all languages (use PRESET=complete)
	$(SCRIPT) -AllCurated -OnlyPreset $(PRESET) -Parallelism $(CURATED_JOBS)

ats: ## Build the three local-only ATS CVs -> dist/
	$(SCRIPT) -Style ats -PhotoMode no-photo

##@ Verification & Quality

check: ## Compile the standard photo CVs in all languages
	$(SCRIPT) -Check

validate-career: ## Validate the AI tailoring career inventory (YAML schema)
	$(PYTHON) scripts/validate-career.py

test: ## Run unit tests (career inventory validation suite)
	$(PYTHON) -m unittest discover -s tests

lint: ## Run chktex on the three .tex sources (requires TeX Live)
	chktex cv_english.tex cv_spanish.tex cv_catalan.tex

##@ Setup & Tooling

hooks: ## Enable tracked git hooks (.githooks/ pre-push guard)
	git config core.hooksPath .githooks
	@echo "Git hooks enabled from .githooks/ (pre-push guards main/master)."

##@ Cleanup

clean: ## Remove build/ (auxiliary files, logs, .xdv)
ifeq ($(OS),Windows_NT)
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue"
else
	rm -rf build
endif

distclean: clean ## Remove build/ and dist/ (also final PDFs)
ifeq ($(OS),Windows_NT)
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue"
else
	rm -rf dist
endif
