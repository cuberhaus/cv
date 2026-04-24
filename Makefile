ENGINE ?= xelatex
FLAGS  ?= -interaction=nonstopmode -halt-on-error

TARGETS = cv_english.pdf cv_spanish.pdf cv_catalan.pdf

.PHONY: all english spanish catalan clean distclean

all: $(TARGETS)

english: cv_english.pdf
spanish: cv_spanish.pdf
catalan: cv_catalan.pdf

cv_english.pdf: cv_english.tex awesome-cv.cls $(wildcard cv/*.tex) profile.jpeg
	$(ENGINE) $(FLAGS) $<
	$(ENGINE) $(FLAGS) $<

cv_spanish.pdf: cv_spanish.tex awesome-cv.cls $(wildcard cv/*.tex) profile.jpeg
	$(ENGINE) $(FLAGS) $<
	$(ENGINE) $(FLAGS) $<

cv_catalan.pdf: cv_catalan.tex awesome-cv.cls $(wildcard cv/*.tex) profile.jpeg
	$(ENGINE) $(FLAGS) $<
	$(ENGINE) $(FLAGS) $<

clean:
	del /Q *.aux *.log *.out *.fls *.fdb_latexmk *.synctex.gz 2>nul || true

distclean: clean
	del /Q $(TARGETS) 2>nul || true
