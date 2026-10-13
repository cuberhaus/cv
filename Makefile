SCRIPT ?= bash scripts/build-local.sh
CURATED_JOBS ?= 4

ifeq ($(OS),Windows_NT)
  PYTHON ?= python
else
  PYTHON ?= python3
endif

.DEFAULT_GOAL := help

.PHONY: help all english spanish catalan \
        curated curated-language curated-preset ats \
        validate-career test \
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
	@echo "  scripts/build-local.sh english --preset technical --photo-mode no-photo"
	@echo "  scripts/build-local.sh catalan --style ats --photo-mode no-photo"

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
	$(SCRIPT) --all-curated --parallelism $(CURATED_JOBS)

curated-language: ## Build one language's public variants (use LANGUAGE=spanish)
	$(SCRIPT) $(LANGUAGE) --all-curated --parallelism $(CURATED_JOBS)

curated-preset: ## Build one preset in all languages (use PRESET=complete)
	$(SCRIPT) --all-curated --only-preset $(PRESET) --parallelism $(CURATED_JOBS)

ats: ## Build the three local-only ATS CVs -> dist/
	$(SCRIPT) --style ats --photo-mode no-photo

##@ Verification & Quality

validate-career: ## Validate the AI tailoring career inventory (YAML schema)
	$(PYTHON) scripts/validate-career.py

test: ## Run unit tests (career inventory, section parity, build script)
	$(PYTHON) -m unittest discover -s tests

##@ Setup & Tooling

hooks: ## Enable tracked git hooks (.githooks/ pre-commit guard)
	git config core.hooksPath .githooks
	@echo "Git hooks enabled from .githooks/ (pre-commit blocks commits on main/master)."

##@ Cleanup

clean: ## Remove build/ (auxiliary files, logs, .xdv)
	rm -rf build

distclean: clean ## Remove build/ and dist/ (also final PDFs)
	rm -rf dist
