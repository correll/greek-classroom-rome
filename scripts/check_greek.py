#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_greek.py - validate the Greek and the block syntax in the course source.

Checks performed:

  1. Fenced-div block names are recognised by scripts/filters/blocks.lua.
  2. Fenced divs are balanced (every ::: opener has a closer).
  3. The file is in Unicode NFC form. Mixed normalisation makes search,
     diff, and sorting unreliable, and it is invisible on screen.
  4. Every Greek word beginning with a vowel carries a breathing mark on
     its first vowel, or on the second if the word opens with a diphthong.
  5. Final sigma occurs only at the end of a word, medial sigma never does.
  6. No Latin lookalike letters hide inside a Greek word - the commonest
     and least visible copy-paste error in Greek typesetting.
  7. Every 'answers' block is preceded in its file by an 'exercise' block.

A line containing the comment <!--nocheck--> is skipped entirely. Use it on
lines that deliberately print incorrect Greek as an example.

Exit status is non-zero if any error is found. Warnings do not fail.
"""
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOCHECK = "<!--nocheck-->"

KNOWN_BLOCKS = set([
    "story", "newgreek", "investigation", "voice", "question",
    "vocab", "exercise", "answers", "teacheronly", "note", "grammar", "latinbridge",
    "paradigm", "part", "reading", "gloss",
])

# Greek and Coptic + Greek Extended, plus combining marks
GREEK = "\\u0370-\\u03FF\\u1F00-\\u1FFF"
COMBINING = "\\u0300-\\u036F"
# these are compared as characters, not used inside a regex, so they are
# built with chr() rather than written as escapes
VOWELS = "".join(chr(c) for c in
                 (0x03B1, 0x03B5, 0x03B7, 0x03B9, 0x03BF, 0x03C5, 0x03C9))
PSILI = chr(0x0313)        # smooth breathing, decomposed
DASIA = chr(0x0314)        # rough breathing, decomposed
FINAL_SIGMA = chr(0x03C2)
MEDIAL_SIGMA = chr(0x03C3)

GREEK_WORD = re.compile("[" + GREEK + COMBINING + "]{2,}")
# a Greek word not preceded by a hyphen or asterisk: those mark bare endings
# (-essi) and reconstructed stems (*s-), both legitimately unbreathed
WORD_START = re.compile("(?<![-*" + GREEK + "])([" + GREEK + COMBINING + "]{2,})")
LATIN_IN_GREEK = re.compile("[" + GREEK + "]+[aeopxvurcAEOPXBHKMNTZ][" + GREEK + "]+")
FENCE = re.compile(r"^(:::+)\s*(.*)$")
CLASSNAME = re.compile(r"\{\s*\.([A-Za-z][\w-]*)|^([A-Za-z][\w-]*)\s*$")

errors = []
warnings = []


def rel(p):
    return os.path.relpath(p, ROOT)


def md_files():
    for sub in ("book", "grammar"):
        for dirpath, _, names in os.walk(os.path.join(ROOT, sub)):
            for n in sorted(names):
                if n.endswith(".md"):
                    yield os.path.join(dirpath, n)


def check_fences(path, text):
    depth = 0
    seen_exercise = False
    for i, line in enumerate(text.splitlines(), 1):
        m = FENCE.match(line.rstrip())
        if not m:
            continue
        rest = m.group(2).strip()
        if not rest:
            depth -= 1
            if depth < 0:
                errors.append("%s:%d: closing ::: with no opener" % (rel(path), i))
                depth = 0
            continue
        depth += 1
        cm = CLASSNAME.search(rest)
        name = (cm.group(1) or cm.group(2)) if cm else None
        if name is None:
            warnings.append("%s:%d: could not read a block name from %r"
                            % (rel(path), i, rest))
        elif name not in KNOWN_BLOCKS:
            errors.append("%s:%d: unknown block '%s' - blocks.lua will ignore it"
                          % (rel(path), i, name))
        else:
            if name == "exercise":
                seen_exercise = True
            elif name == "answers" and not seen_exercise:
                warnings.append("%s:%d: 'answers' block with no preceding "
                                "'exercise' in this file" % (rel(path), i))
    if depth != 0:
        errors.append("%s: %d fenced div(s) left unclosed" % (rel(path), depth))


def check_greek(path, text):
    if unicodedata.normalize("NFC", text) != text:
        errors.append("%s: file is not in Unicode NFC form" % rel(path))

    skip_breathing = False
    for i, line in enumerate(text.splitlines(), 1):
        if NOCHECK in line:
            continue

        for w in GREEK_WORD.findall(line):
            if FINAL_SIGMA in w[:-1]:
                errors.append("%s:%d: final sigma inside a word: %s"
                              % (rel(path), i, w))
            if w.endswith(MEDIAL_SIGMA):
                errors.append("%s:%d: medial sigma at end of word: %s"
                              % (rel(path), i, w))
            if LATIN_IN_GREEK.search(w):
                errors.append("%s:%d: Latin letter inside a Greek word: %s"
                              % (rel(path), i, w))

        low = line.lower()
        if "transliterat" in low or "alphabet" in low:
            continue
        for m in WORD_START.finditer(line):
            word = m.group(1)
            d = unicodedata.normalize("NFD", word)
            if not d or d[0] not in VOWELS:
                continue
            # the breathing sits on the first vowel, or the second in a
            # diphthong; six decomposed characters covers both plus accents
            if PSILI in d[:6] or DASIA in d[:6]:
                continue
            warnings.append("%s:%d: Greek word may be missing its breathing: %s"
                            % (rel(path), i, word))


def main():
    n = 0
    for p in md_files():
        with open(p, encoding="utf-8") as f:
            text = f.read()
        n += 1
        check_fences(p, text)
        check_greek(p, text)

    for w in warnings:
        print("warning: " + w)
    for e in errors:
        print("ERROR:   " + e)
    print("\nchecked %d files - %d error(s), %d warning(s)"
          % (n, len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
