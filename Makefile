# ---------------------------------------------------------------
#  The Greek Classroom of Rome, AD 400
#  make pdf | teacher | grammar | site | all | check | clean
# ---------------------------------------------------------------

PANDOC   ?= pandoc
ENGINE   ?= xelatex
BUILD    := build
SITE     := site
FONTDIR  := $(abspath assets/fonts)/

FROM     := markdown+fenced_divs+bracketed_spans+pipe_tables+smart+implicit_figures+raw_tex
FILTER   := --lua-filter=scripts/filters/blocks.lua

BOOK_SRC    := book/metadata.yaml \
               $(sort $(wildcard book/front/*.md)) \
               $(sort $(wildcard book/part1/*.md)) \
               $(sort $(wildcard book/part2/*.md)) \
               $(sort $(wildcard book/part3/*.md)) \
               $(sort $(wildcard book/part4/*.md)) \
               $(sort $(wildcard book/part5/*.md)) \
               $(sort $(wildcard book/back/*.md))

GRAM_SRC    := grammar/metadata.yaml $(sort $(wildcard grammar/*.md))

# PDFs are built in two stages - pandoc to .tex, then XeLaTeX - rather than
# letting pandoc drive the engine in a temporary directory. It costs nothing
# and it means the LaTeX log survives a failure, which is the difference
# between a diagnosable CI run and a guess.
TEXOPTS  := --from=$(FROM) $(FILTER) \
            --template=templates/book.latex \
            --top-level-division=chapter \
            --toc --toc-depth=1 \
            --variable=fontdir:"$(FONTDIR)"

STUDENT_FLAGS := --metadata=edition:student
TEACHER_FLAGS := --metadata=edition:teacher \
                 --metadata=subtitle="Teacher's Edition · with answer keys"
GRAMMAR_FLAGS := --toc-depth=2 --number-sections --metadata=edition:student

TEXDIR   := $(BUILD)/tex
XELATEX  := $(ENGINE) -interaction=nonstopmode -file-line-error -halt-on-error

# $(1) extra pandoc flags, $(2) job name, $(3) source list
define build_pdf
@mkdir -p $(TEXDIR)
$(PANDOC) $(TEXOPTS) $(1) $(3) -o $(TEXDIR)/$(2).tex
cd $(TEXDIR) && $(XELATEX) $(2).tex >/dev/null 2>&1 || \
  { echo; echo "XeLaTeX failed - $(TEXDIR)/$(2).log:"; \
    sed -n "/^.*:[0-9]*: /,$$$$p" $(2).log | head -40; exit 1; }
@cd $(TEXDIR) && $(XELATEX) $(2).tex >/dev/null 2>&1
@cd $(TEXDIR) && $(XELATEX) $(2).tex >/dev/null 2>&1
@cp $(TEXDIR)/$(2).pdf $@
@echo "  -> $@"
endef

.PHONY: all pdf teacher grammar site check glossary clean distclean fonts help

all: pdf teacher grammar site

help:
	@echo "make pdf      - student edition PDF      -> $(BUILD)/greek-classroom.pdf"
	@echo "make teacher  - teacher edition PDF      -> $(BUILD)/greek-classroom-teacher.pdf"
	@echo "make grammar  - reference grammar PDF    -> $(BUILD)/greek-grammar.pdf"
	@echo "make site     - GitHub Pages site        -> $(SITE)/"
	@echo "make check    - validate Greek text and block syntax"
	@echo "make glossary - regenerate the cumulative vocabulary from the lessons"
	@echo "make fonts    - (re)download the vendored OFL fonts"
	@echo "make clean    - remove build output"

$(BUILD):
	@mkdir -p $(BUILD)

pdf: $(BUILD)/greek-classroom.pdf
$(BUILD)/greek-classroom.pdf: $(BOOK_SRC) templates/book.latex scripts/filters/blocks.lua | $(BUILD)
	$(call build_pdf,$(STUDENT_FLAGS),greek-classroom,$(BOOK_SRC))

teacher: $(BUILD)/greek-classroom-teacher.pdf
$(BUILD)/greek-classroom-teacher.pdf: $(BOOK_SRC) templates/book.latex scripts/filters/blocks.lua | $(BUILD)
	$(call build_pdf,$(TEACHER_FLAGS),greek-classroom-teacher,$(BOOK_SRC))

grammar: $(BUILD)/greek-grammar.pdf
$(BUILD)/greek-grammar.pdf: $(GRAM_SRC) templates/book.latex scripts/filters/blocks.lua | $(BUILD)
	$(call build_pdf,$(GRAMMAR_FLAGS),greek-grammar,$(GRAM_SRC))

site: pdf teacher grammar
	python3 scripts/build_site.py
	@echo "  -> $(SITE)/index.html"

check:
	python3 scripts/check_greek.py

glossary:
	python3 scripts/build_glossary.py

fonts:
	bash scripts/fetch_fonts.sh

clean:
	rm -rf $(BUILD) $(SITE)

distclean: clean
	rm -f assets/fonts/*.ttf
