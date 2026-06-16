SCRIPT = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1

.DEFAULT_GOAL := help

.PHONY: help all english spanish catalan check clean distclean hooks lint

help:
	@echo "CV build targets:"
	@echo "  make all        Build all 3 canonical CVs (no certifications) -> dist/"
	@echo "  make english    Build canonical cv_english.pdf -> dist/"
	@echo "  make spanish    Build canonical cv_spanish.pdf -> dist/"
	@echo "  make catalan    Build canonical cv_catalan.pdf -> dist/"
	@echo "  make check      Build all + fail if canonical variant overflows to 2+ pages"
	@echo "  make lint       Run chktex on the three .tex sources (requires TeX Live)"
	@echo "  make clean      Remove build/ (aux, logs, .xdv)"
	@echo "  make distclean  Remove build/ and dist/ (also final PDFs)"
	@echo "  make hooks      Enable tracked git hooks (pre-push guard against direct pushes to main/master)"
	@echo "  make help       Show this message"
	@echo ""
	@echo "Custom variants (toggles c=certifications, e=extracurricular, p=projects, s=skills):"
	@echo "  pwsh scripts/build-local.ps1 english -Toggles 1111  # all on"
	@echo "  pwsh scripts/build-local.ps1 english -Toggles 0000  # minimum (summary+education+experience)"
	@echo "  pwsh scripts/build-local.ps1 -Toggles 1011          # certifications + projects + skills, no extracurricular"
	@echo "  CI builds all 16 toggle combos x 3 langs = 48 variants on every push to main."

all:
	$(SCRIPT)

english:
	$(SCRIPT) english

spanish:
	$(SCRIPT) spanish

catalan:
	$(SCRIPT) catalan

check:
	$(SCRIPT) -Check

lint:
	chktex cv_english.tex cv_spanish.tex cv_catalan.tex

clean:
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue"

distclean: clean
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue"

hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks enabled from .githooks/ (pre-push guards main/master)."

