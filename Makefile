SCRIPT = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build-local.ps1

.PHONY: all english spanish catalan check clean distclean

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

