# The Greek Classroom of Rome, AD 400

A Classical Greek course for grades 7–9, built as a continuing story.

Rome, autumn of AD 400. Eight Latin-speaking children in a household school
on the Caelian Hill are made to study Greek by a grammarian from Antioch.
They find the language old-fashioned, the declensions infuriating, and
their teacher's expectations unreasonable. Over thirty lessons they
discover that the ancient authors are not dusty authorities but people who
asked questions that still matter.

One source tree produces four things:

| | |
|:--|:--|
| `build/greek-classroom.pdf` | the textbook, student edition |
| `build/greek-classroom-teacher.pdf` | the same book with answer keys inline |
| `build/greek-grammar.pdf` | the companion reference grammar |
| `site/` | a GitHub Pages site with the same content and the PDFs |

## Quick start

```sh
make           # everything
make pdf       # student edition only
make site      # the website (builds the PDFs first)
make check     # validate the Greek and the block syntax
make help      # all targets
```

## Requirements

| | |
|:--|:--|
| **Pandoc** | 2.9 or newer |
| **XeLaTeX** | from TeX Live 2021 or newer, with `latex-extra` for `tcolorbox` |
| **Python** | 3.8+, with `fonttools` and `brotli` for the site's web fonts |

Everything else — the Greek fonts included — is vendored in `assets/`.

On Debian or Ubuntu:

```sh
sudo apt-get install pandoc texlive-xetex texlive-latex-extra \
                     texlive-fonts-recommended lmodern
pip install fonttools brotli
```

On macOS with Homebrew:

```sh
brew install pandoc
brew install --cask mactex-no-gui    # or basictex + tlmgr install tcolorbox
pip3 install fonttools brotli
```

## Repository layout

```
book/                 the textbook
  metadata.yaml       title, author, defaults
  front/              preface, note to students, the school, pronunciation,
                      scope and sequence
  part1/ … part5/     00-part.md is the part divider; the rest are lessons
  back/               editions note, generated glossary, sources
grammar/              the reference grammar, §1–§17
templates/book.latex  the XeLaTeX template: page design, boxes, title page
scripts/
  filters/blocks.lua  maps the authoring blocks to LaTeX and HTML
  build_site.py       builds site/ from the same Markdown
  build_glossary.py   regenerates book/back/02-vocabulary.md
  check_greek.py      validates Greek text and block syntax
  fetch_fonts.sh      re-downloads the vendored OFL fonts
assets/
  fonts/              Gentium Book Plus, GFS Didot, and their licences
  css/site.css        the website's styles
.github/workflows/    CI: validate, build, deploy to Pages
```

## Writing a lesson

Lessons are Markdown with a small set of named blocks. The blocks are what
give the book its structure, and the same source produces both the print
and the web layout.

````markdown
# The Unwelcome Tablet

::: {.story time="5 min"}
Marcus arrived late…
:::

::: {.newgreek time="10 min"}
## Twenty-four letters
The Greek alphabet has twenty-four letters…
:::

::: vocab
- **ὁ λόγος** — word, speech, account
- **ὁ φίλος** — friend
:::

::: {.investigation time="15 min"}
::: {.exercise title="Sound them out"}
1. Write each word in Latin letters.
:::

::: answers
*philos* · *logos* · …
:::
:::

::: {.voice time="10 min" source="Plato, *Charmides* 164e"}
**γνῶθι σαυτόν**
:::

::: {.question time="5 min"}
What exactly did you do when you read that?
:::
````

### All the blocks

| Block | Where it appears |
|:--|:--|
| `.story` | the classroom scene — terracotta bar, italic |
| `.newgreek` | the grammar — tinted panel |
| `.investigation` | exercises — plain, with its own rubric |
| `.voice` | the ancient text — blue bar, source on the right |
| `.question` | the closing reflection — olive bar |
| `vocab` | words to learn — compact list |
| `.exercise` | numbered automatically per lesson; `title=` is optional |
| `answers` | **teacher's edition only**; hidden in the student PDF |
| `note` | an aside |
| `latinbridge` | a *From Latin* box |
| `.part` | a part divider; takes `name=` and `goal=` |

### Inline

| | |
|:--|:--|
| `[λόγος]{.gk}` | Greek with display letterspacing |
| `[§4.2]{.gref}` | a cross-reference to the grammar volume |
| `[ ]{.gap}` | a blank for the student to fill in |

Attribute values are plain text, except that `*asterisks*` are honoured as
italics in `source=`.

### After drafting a lesson

```sh
make glossary   # regenerate the cumulative vocabulary
make check      # catch block and Greek errors before they reach the PDF
make pdf
```

`make check` validates fenced-div balance and block names, Unicode NFC
normalisation, breathing marks on initial vowels, final-sigma placement,
and Latin letters hiding inside Greek words. Put `<!--nocheck-->` on a line
that deliberately prints incorrect Greek as an example.

## Drafting status

| | |
|:--|:--|
| Front matter | complete |
| Lessons 1–3 | written in full, with exercises and answer keys |
| Lessons 4–30 | outlined — grammar focus, story premise, text target, and vocabulary planned for each |
| Grammar §1–§5 | complete: writing and sound, accentuation, the article, the first and second declensions |
| Grammar §6–§16 | outlined, with numbering already stable |
| Grammar §17 | paradigm appendix, populated for everything taught so far |

Cross-references to the outlined grammar sections are already valid, so
drafting can proceed in any order without renumbering.

## Decisions worth knowing about

**Pronunciation.** The course teaches reconstructed Classical Attic, and
says so explicitly, with the differences from Erasmian and Modern Greek
noted where they matter. See `book/front/04-pronunciation.md`.

**Attic first.** Classical Attic is the core language. Homer's epic dialect
and the Koine of the Septuagint and New Testament arrive later, labelled as
distinct, never blurred together.

**Composed sentences are marked.** Every sentence written for teaching says
so. Every passage attributed to an ancient author is quoted and cited. A
student should never be in doubt which is which.

**Two editions, one source.** The answer keys live beside their exercises
in the same file. The student PDF drops them at build time, so the two
editions cannot drift apart.

## Deploying

Push to `main`. The workflow in `.github/workflows/build.yml` validates the
source, builds all three PDFs and the site, and deploys to GitHub Pages.
Enable Pages once under **Settings → Pages → Source → GitHub Actions**.

The PDFs are also attached to every run as a build artefact, so a pull
request can be reviewed as a PDF without building it locally.

## Licence

Course text, lessons, and grammar: **CC BY-NC-SA 4.0**.
Build system, templates, filters, and scripts: **MIT**.
Fonts: **SIL Open Font License 1.1** — see `assets/fonts/`.

Ancient texts quoted in the course are from public-domain editions, listed
in `book/back/03-sources.md`.
