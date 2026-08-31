SCRIPT = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1

.DEFAULT_GOAL := help

.PHONY: help all curated english spanish catalan ats check validate-career clean distclean hooks lint

help:
	@echo "CV build targets:"
	@echo "  make all        Build standard photo CVs in all languages -> dist/"
	@echo "  make curated    Build all public preset/photo combinations -> dist/"
	@echo "  make english    Build standard photo English CV -> dist/"
	@echo "  make spanish    Build standard photo Spanish CV -> dist/"
	@echo "  make catalan    Build standard photo Catalan CV -> dist/"
	@echo "  make ats        Build the three local-only ATS CVs -> dist/"
	@echo "  make check      Compile the standard photo CVs in all languages"
	@echo "  make validate-career  Validate the AI tailoring inventory"
	@echo "  make lint       Run chktex on the three .tex sources (requires TeX Live)"
	@echo "  make clean      Remove build/ (aux, logs, .xdv)"
	@echo "  make distclean  Remove build/ and dist/ (also final PDFs)"
	@echo "  make hooks      Enable tracked git hooks (pre-push guard against direct pushes to main/master)"
	@echo "  make help       Show this message"
	@echo ""
	@echo "Public presets: standard, technical, complete, concise. Photo modes: photo, no-photo."
	@echo "  pwsh scripts/build-local.ps1 english -Preset technical -PhotoMode no-photo"
	@echo "  pwsh scripts/build-local.ps1 catalan -Style ats -PhotoMode no-photo"

all:
	$(SCRIPT)

english:
	$(SCRIPT) english

spanish:
	$(SCRIPT) spanish

catalan:
	$(SCRIPT) catalan

curated:
	$(SCRIPT) -AllCurated

ats:
	$(SCRIPT) -Style ats -PhotoMode no-photo

check:
	$(SCRIPT) -Check

validate-career:
	python scripts/validate-career.py

lint:
	chktex cv_english.tex cv_spanish.tex cv_catalan.tex

clean:
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue"

distclean: clean
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue"

hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks enabled from .githooks/ (pre-push guards main/master)."


##@ Understand (knowledge graph)

.PHONY: understand-dashboard
understand-dashboard: ## Launch the Understand Anything knowledge-graph dashboard (graph dir = repo root)
	@node -e "require(require('os').homedir()+'/.understand-anything/repo/understand-anything-plugin/packages/dashboard/launch.cjs')"
