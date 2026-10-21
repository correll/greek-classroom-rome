# ---------------------------------------------------------------
#  Schola Graeca
#  make pdf | teacher | grammar | site | all | check | clean
# ---------------------------------------------------------------

PANDOC   ?= pandoc
ENGINE   ?= xelatex
BUILD    := build
SITE     := site
FONTDIR  := $(abspath assets/fonts)/

FROM     := markdown+fenced_divs+bracketed_spans+pipe_tables+smart+implicit_figures+raw_tex
FILTER   := --lua-filter=scripts/filters/blocks.lua \
            --lua-filter=scripts/filters/studentpages.lua

# book/teacher/ holds whole chapters that belong only to the teacher's
# edition - the character notes and staging. Short teacher-only passages
# inside a lesson use a ::: teacheronly block instead.
FRONT_SRC   := book/metadata.yaml $(sort $(wildcard book/front/*.md))
TEACH_SRC   := $(sort $(wildcard book/teacher/*.md))
BODY_SRC    := $(sort $(wildcard book/part1/*.md)) \
               $(sort $(wildcard book/part2/*.md)) \
               $(sort $(wildcard book/part3/*.md)) \
               $(sort $(wildcard book/part4/*.md)) \
               $(sort $(wildcard book/part5/*.md)) \
               $(sort $(wildcard book/part6/*.md)) \
               $(sort $(wildcard book/back/*.md))

BOOK_SRC    := $(FRONT_SRC) $(BODY_SRC)
# the teacher's edition puts its first chapter (how the book uses the
# research on learning) straight after the preface
TEACH_FIRST := $(sort $(wildcard book/teacher/00-*.md))
TEACH_REST  := $(filter-out $(TEACH_FIRST),$(TEACH_SRC))
TEACHER_BOOK_SRC := book/metadata.yaml book/front/01-preface.md $(TEACH_FIRST) \
                    $(filter-out book/metadata.yaml book/front/01-preface.md,$(FRONT_SRC)) \
                    $(TEACH_REST) $(BODY_SRC)

GRAM_SRC    := grammar/metadata.yaml $(sort $(wildcard grammar/*.md))

# The teacher's edition cites the student edition's page numbers, which only
# exist once the student edition has been typeset. The map is harvested from
# its .aux file, so the teacher PDF depends on it and make orders the two.
STUDENT_PAGES := $(BUILD)/student-pages.lua

# PDFs are built in two stages - pandoc to .tex, then XeLaTeX - rather than
# letting pandoc drive the engine in a temporary directory. It costs nothing
# and it means the LaTeX log survives a failure, which is the difference
# between a diagnosable CI run and a guess.
TEXOPTS  := --from=$(FROM) $(FILTER) \
            --template=templates/book.latex \
            --top-level-division=chapter \
            --toc --toc-depth=2 \
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

.PHONY: all pdf teacher grammar site lulu kdp epub check glossary clean distclean fonts help

all: pdf teacher grammar site

help:
	@echo "make pdf      - student edition PDF      -> $(BUILD)/greek-classroom.pdf"
	@echo "make teacher  - teacher edition PDF      -> $(BUILD)/greek-classroom-teacher.pdf"
	@echo "make grammar  - reference grammar PDF    -> $(BUILD)/greek-grammar.pdf"
	@echo "make site     - GitHub Pages site        -> $(SITE)/"
	@echo "make kdp      - Amazon KDP paperback: interior and covers -> $(BUILD)/kdp/"
	@echo "make epub     - Kindle/EPUB ebook and its cover -> $(BUILD)/greek-classroom.epub"
	@echo "make lulu     - Lulu hardcover upload: interiors and wrap covers -> $(BUILD)/lulu/"
	@echo "make check    - validate Greek text and block syntax"
	@echo "make glossary - regenerate the cumulative vocabulary from the lessons"
	@echo "make fonts    - (re)download the vendored OFL fonts"
	@echo "make clean    - remove build output"

$(BUILD):
	@mkdir -p $(BUILD)

pdf: $(BUILD)/greek-classroom.pdf
$(BUILD)/greek-classroom.pdf: $(BOOK_SRC) templates/book.latex scripts/filters/blocks.lua scripts/filters/studentpages.lua | $(BUILD)
	$(call build_pdf,$(STUDENT_FLAGS),greek-classroom,$(BOOK_SRC))

$(STUDENT_PAGES): $(BUILD)/greek-classroom.pdf scripts/student_pages.py | $(BUILD)
	python3 scripts/student_pages.py $(TEXDIR)/greek-classroom.aux $@

teacher: $(BUILD)/greek-classroom-teacher.pdf
$(BUILD)/greek-classroom-teacher.pdf: $(TEACHER_BOOK_SRC) templates/book.latex scripts/filters/blocks.lua scripts/filters/studentpages.lua $(STUDENT_PAGES) | $(BUILD)
	$(call build_pdf,$(TEACHER_FLAGS),greek-classroom-teacher,$(TEACHER_BOOK_SRC))

grammar: $(BUILD)/greek-grammar.pdf
$(BUILD)/greek-grammar.pdf: $(GRAM_SRC) templates/book.latex scripts/filters/blocks.lua scripts/filters/studentpages.lua | $(BUILD)
	$(call build_pdf,$(GRAMMAR_FLAGS),greek-grammar,$(GRAM_SRC))

site: pdf teacher grammar
	python3 scripts/build_site.py
	@echo "  -> $(SITE)/index.html"

# Lulu hardcover (casewrap): the interior is the edition PDF with 0.125 in
# of white bleed added all round (7.25 x 10.25 in, trim box at 7 x 10);
# the wrap cover is generated to Lulu's template, its spine sized from the
# interior's page count. See scripts/lulu_cover.py.
LULU := $(BUILD)/lulu
lulu: $(BUILD)/greek-classroom.pdf $(BUILD)/greek-classroom-teacher.pdf scripts/lulu_cover.py scripts/lulu_bleed.py
	@mkdir -p $(LULU)
	python3 scripts/lulu_bleed.py $(BUILD)/greek-classroom.pdf $(LULU)/greek-classroom-interior.pdf
	python3 scripts/lulu_bleed.py $(BUILD)/greek-classroom-teacher.pdf $(LULU)/greek-classroom-teacher-interior.pdf
	python3 scripts/lulu_cover.py $(LULU)/greek-classroom-interior.pdf $(LULU)/greek-classroom-cover.pdf
	python3 scripts/lulu_cover.py $(LULU)/greek-classroom-teacher-interior.pdf $(LULU)/greek-classroom-teacher-cover.pdf \
	  --subtitle "Teacher's Edition · with answer keys"

# Amazon KDP paperback, 7 x 10 in, interior without bleed: the student PDF
# as it is, and the wrap cover in KDP's geometry (0.125 in bleed, spine from
# KDP's per-page formula). One cover per colour paper, since the spine differs.
KDP := $(BUILD)/kdp
kdp: $(BUILD)/greek-classroom.pdf scripts/lulu_cover.py
	@mkdir -p $(KDP)
	cp $(BUILD)/greek-classroom.pdf $(KDP)/greek-classroom-kdp-interior.pdf
	python3 scripts/lulu_cover.py $(KDP)/greek-classroom-kdp-interior.pdf $(KDP)/greek-classroom-kdp-cover-standard-color.pdf --kdp-paperback standard-color
	python3 scripts/lulu_cover.py $(KDP)/greek-classroom-kdp-interior.pdf $(KDP)/greek-classroom-kdp-cover-premium-color.pdf --kdp-paperback premium-color

# The ebook: the student edition as a reflowable EPUB 3, which Kindle
# Direct Publishing takes directly. Same sources and filter as the print
# book, plus ebook.lua (part pages and lesson numbers) and a stylesheet
# Kindle can render. The fonts are embedded so the polytonic Greek shows
# whatever the device has installed; the reader can still choose another.
EPUB_FONTS := $(foreach f,GentiumBookPlus-Regular GentiumBookPlus-Bold GentiumBookPlus-Italic GentiumBookPlus-BoldItalic GFSDidot-Regular,--epub-embed-font=assets/fonts/$(f).ttf)
epub: $(BUILD)/greek-classroom.epub
$(BUILD)/ebook-cover.jpg: scripts/ebook_cover.py assets/illustrations/cover.jpg | $(BUILD)
	python3 scripts/ebook_cover.py $@
$(BUILD)/greek-classroom.epub: $(BOOK_SRC) scripts/filters/ebook.lua scripts/filters/blocks.lua assets/css/epub.css $(BUILD)/ebook-cover.jpg | $(BUILD)
	$(PANDOC) --from=$(FROM) --to=epub3 \
	  --lua-filter=scripts/filters/ebook.lua --lua-filter=scripts/filters/blocks.lua \
	  --metadata=edition:student \
	  --metadata=cover-image:$(BUILD)/ebook-cover.jpg \
	  --metadata=rights:"Text CC BY-NC-SA 4.0; fonts SIL OFL 1.1" \
	  --css=assets/css/epub.css $(EPUB_FONTS) \
	  --toc --toc-depth=1 --split-level=1 \
	  $(BOOK_SRC) -o $@
	@echo "  -> $@"

check:
	python3 scripts/check_greek.py
	python3 scripts/check_refs.py

glossary:
	python3 scripts/build_glossary.py

fonts:
	bash scripts/fetch_fonts.sh

clean:
	rm -rf $(BUILD) $(SITE)

distclean: clean
	rm -f assets/fonts/*.ttf
