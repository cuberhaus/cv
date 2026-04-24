SCRIPT = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1

.DEFAULT_GOAL := help

.PHONY: help all english spanish catalan check clean distclean

help:
	@echo "CV build targets:"
	@echo "  make all        Build all 3 CVs (English, Spanish, Catalan) -> dist/"
	@echo "  make english    Build cv_english.pdf -> dist/"
	@echo "  make spanish    Build cv_spanish.pdf -> dist/"
	@echo "  make catalan    Build cv_catalan.pdf -> dist/"
	@echo "  make check      Build all + fail if any CV overflows to 2+ pages"
	@echo "  make clean      Remove build/ (aux, logs, .xdv)"
	@echo "  make distclean  Remove build/ and dist/ (also final PDFs)"
	@echo "  make help       Show this message"

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

clean:
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue"

distclean: clean
	pwsh -NoProfile -Command "Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue"

