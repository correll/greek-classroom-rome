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

PDFOPTS  := --from=$(FROM) $(FILTER) \
            --template=templates/book.latex \
            --pdf-engine=$(ENGINE) \
            --top-level-division=chapter \
            --toc --toc-depth=1 \
            --variable=fontdir:"$(FONTDIR)"

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
	$(PANDOC) $(PDFOPTS) --metadata=edition:student $(BOOK_SRC) -o $@
	@echo "  -> $@"

teacher: $(BUILD)/greek-classroom-teacher.pdf
$(BUILD)/greek-classroom-teacher.pdf: $(BOOK_SRC) templates/book.latex scripts/filters/blocks.lua | $(BUILD)
	$(PANDOC) $(PDFOPTS) --metadata=edition:teacher \
	  --metadata=subtitle:"Teacher's Edition · with answer keys" \
	  $(BOOK_SRC) -o $@
	@echo "  -> $@"

grammar: $(BUILD)/greek-grammar.pdf
$(BUILD)/greek-grammar.pdf: $(GRAM_SRC) templates/book.latex scripts/filters/blocks.lua | $(BUILD)
	$(PANDOC) $(PDFOPTS) --toc-depth=2 --number-sections --metadata=edition:student $(GRAM_SRC) -o $@
	@echo "  -> $@"

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
