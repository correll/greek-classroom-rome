#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_glossary.py - regenerate book/back/02-vocabulary.md from the lessons.

Reads every 'vocab' block in book/part*/??-lesson-NN.md, extracts the
headwords and glosses, and writes a single alphabetised list with the
lesson number that introduces each word.

Two authoring forms are understood:

    - **ho logos** - word, speech, account          (one per line)
    - **ho logos** word . **ho philos** friend      (middle-dot separated)

Entries are sorted by the Greek alphabet, ignoring the article, accents,
and breathings. Run `make glossary` after drafting a lesson.
"""
import io
import os
import re
import sys
import unicodedata
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "book", "back", "02-vocabulary.md")
OUT_EN = os.path.join(ROOT, "book", "back", "03-english-greek.md")

ARTICLES = ("ὁ ", "ἡ ", "τὸ ", "τὰ ",
            "οἱ ", "αἱ ", "τὰ ")
MIDDOT = "·"
ALPHABET = [chr(c) for c in range(0x0391, 0x03AA) if c != 0x03A2]

VOCAB_OPEN = re.compile(r"^:::+\s*(?:\{\s*\.)?vocab\b")
FENCE_ANY = re.compile(r"^:::+")
ENTRY = re.compile(r"\*\*(?P<lemma>[^*]+?)\*\*\s*(?:[—–-]\s*)?"
                   r"(?P<gloss>[^" + MIDDOT + r"\n]*)")
LESSON_FILE = re.compile(r"lesson-(\d{2})\.md$")


def fold(s):
    """Sort key: drop the article, accents, breathings, and case."""
    for a in ARTICLES:
        if s.startswith(a):
            s = s[len(a):]
            break
    d = unicodedata.normalize("NFD", s)
    d = "".join(c for c in d if not unicodedata.combining(c))
    return d.lower()


def first_letter(s):
    f = fold(s)
    return f[0].upper() if f else "?"


def lesson_files():
    out = []
    for part in sorted(os.listdir(os.path.join(ROOT, "book"))):
        d = os.path.join(ROOT, "book", part)
        if not (part.startswith("part") and os.path.isdir(d)):
            continue
        for n in sorted(os.listdir(d)):
            m = LESSON_FILE.search(n)
            if m:
                out.append((int(m.group(1)), os.path.join(d, n)))
    return sorted(out)


def vocab_blocks(text):
    """Yield the body of each vocab block, ignoring nested blocks."""
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        if VOCAB_OPEN.match(lines[i]):
            depth = 1
            body = []
            i += 1
            while i < len(lines) and depth > 0:
                if FENCE_ANY.match(lines[i]):
                    if re.match(r"^:::+\s*$", lines[i]):
                        depth -= 1
                    else:
                        depth += 1
                    i += 1
                    continue
                # only the vocab block's own lines count; a nested note or
                # exercise inside it is commentary, not vocabulary
                if depth == 1:
                    body.append(lines[i])
                i += 1
            yield "\n".join(unwrap(body))
        i += 1


def unwrap(lines):
    """Join the continuation lines of a wrapped list item onto its first
    line, so that an entry whose gloss runs over is read whole and a bold
    form on its second line is not mistaken for a new headword."""
    out = []
    for line in lines:
        if out and line.startswith("  ") and line.strip() \
                and not re.match(r"^\s*[-*]\s+", line) \
                and re.match(r"^[-*]\s+", out[-1]):
            out[-1] = out[-1].rstrip() + " " + line.strip()
        else:
            out.append(line)
    return out


LEADIN = re.compile(r"^(?:I|to|the|a|an|he|she|it|they|we|you)\s+")
PAREN = re.compile(r"\*?\([^)]*\)\*?")


def senses(gloss):
    """Split an English gloss into the headwords a student would look up."""
    g = PAREN.sub("", gloss).replace("*", "")
    g = re.sub(r"\bhe, she, or it\s+", "", g)
    out = []
    for piece in re.split(r"[;,]", g):
        t = piece.strip(" .;:·—–-")
        t = LEADIN.sub("", t).strip()
        # a long phrase is an explanation, not a word to look up under
        if not t or len(t.split()) > 4:
            continue
        out.append(t)
    return out


def write_english_greek(entries):
    """book/back/03-english-greek.md - the list that lets a pupil compose."""
    rev = defaultdict(list)
    for lemma, (gloss, lesson) in entries.items():
        seen = set()
        for sense in senses(gloss):
            k = sense.lower()
            if k in seen:
                continue
            seen.add(k)
            rev[k].append((sense, lemma, lesson))

    groups = defaultdict(list)
    for k, vals in rev.items():
        groups[k[0].upper() if k else "?"].append((k, vals))

    out = [
        "# English to Greek {.unnumbered}",
        "",
        "The vocabulary list the other way round, for when you are composing",
        "rather than translating. Look the English up here, then check the",
        "word in the Greek list, which gives the article and the lesson it",
        "came from.",
        "",
        "Where one English word answers to several Greek ones, all of them are",
        "given. They are rarely interchangeable, and choosing between them is",
        "most of what composing well consists of.",
        "",
        "Generated by `scripts/build_glossary.py`; run `make glossary` rather",
        "than editing it by hand.",
        "",
    ]
    total = 0
    for letter in sorted(groups):
        out.append("## " + letter)
        out.append("")
        out.append("| | | |")
        out.append("|:--|:--|:--:|")
        for _, vals in sorted(groups[letter]):
            disp = vals[0][0]
            greek = ", ".join("**%s**" % v[1] for v in sorted(vals, key=lambda v: v[2]))
            lessons = ", ".join(str(v[2]) for v in sorted(vals, key=lambda v: v[2]))
            out.append("| %s | %s | %s |" % (disp, greek, lessons))
            total += 1
        out.append("")

    io.open(OUT_EN, "w", encoding="utf-8").write("\n".join(out))
    return total


def main():
    entries = {}
    for lesson, path in lesson_files():
        text = io.open(path, encoding="utf-8").read()
        for block in vocab_blocks(text):
            for line in block.split("\n"):
                s = line.strip()
                if not s or s.startswith(">") or s.startswith("#"):
                    continue
                s = re.sub(r"^[-*]\s+", "", s)
                for m in ENTRY.finditer(s):
                    lemma = m.group("lemma").strip()
                    gloss = m.group("gloss").strip(" .;")
                    if not lemma or not gloss:
                        continue
                    if lemma not in entries:
                        entries[lemma] = (gloss, lesson)

    groups = defaultdict(list)
    for lemma, (gloss, lesson) in entries.items():
        groups[first_letter(lemma)].append((fold(lemma), lemma, gloss, lesson))

    out = [
        "# Cumulative Vocabulary {.unnumbered}",
        "",
        "Every word introduced in the course, with the lesson that introduces",
        "it. Nouns are given with the article, verbs in the first person",
        "singular present, adjectives in the masculine nominative singular.",
        "",
        "This list is generated from the `vocab` blocks in the lesson files by",
        "`scripts/build_glossary.py`. Do not edit it by hand: run",
        "`make glossary` after drafting a lesson and it will be rebuilt.",
        "",
    ]
    total = 0
    for letter in ALPHABET:
        if letter not in groups:
            continue
        out.append("## " + letter)
        out.append("")
        out.append("| | | |")
        out.append("|:--|:--|:--:|")
        for _, lemma, gloss, lesson in sorted(groups[letter]):
            out.append("| **%s** | %s | %d |" % (lemma, gloss, lesson))
            total += 1
        out.append("")

    leftovers = sorted(k for k in groups if k not in ALPHABET)
    for letter in leftovers:
        out.append("## " + letter)
        out.append("")
        out.append("| | | |")
        out.append("|:--|:--|:--:|")
        for _, lemma, gloss, lesson in sorted(groups[letter]):
            out.append("| **%s** | %s | %d |" % (lemma, gloss, lesson))
            total += 1
        out.append("")

    io.open(OUT, "w", encoding="utf-8").write("\n".join(out))
    print("wrote %s - %d entries from %d lessons"
          % (os.path.relpath(OUT, ROOT), total, len(lesson_files())))

    n = write_english_greek(entries)
    print("wrote %s - %d headwords" % (os.path.relpath(OUT_EN, ROOT), n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
