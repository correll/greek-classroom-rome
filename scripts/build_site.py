#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_site.py - build the GitHub Pages site from the same Markdown sources
that produce the PDFs.

One HTML page per source file, a shared navigation sidebar, a landing page,
and copies of whatever PDFs are in build/. Pandoc does the Markdown; this
script does the chrome.

Run via `make site`.
"""
import io
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "site")
BUILD = os.path.join(ROOT, "build")
PANDOC = os.environ.get("PANDOC", "pandoc")

FROM = ("markdown+fenced_divs+bracketed_spans+pipe_tables+smart"
        "+implicit_figures+raw_tex")
FILTER = os.path.join(ROOT, "scripts", "filters", "blocks.lua")

TITLE = "The Greek Classroom of Rome, AD 400"
SUBTITLE = "A Classical Greek course for grades 7-9"
REPO = os.environ.get("REPO_URL", "")


def sh(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        sys.stderr.write(" ".join(cmd) + "\n" + p.stderr + "\n")
        raise SystemExit(p.returncode)
    return p.stdout


def heading_of(path):
    """First ATX heading in the file, minus any pandoc attribute block."""
    with io.open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("# "):
                h = line[2:].strip()
                return re.sub(r"\s*\{[^}]*\}\s*$", "", h).strip()
    return os.path.basename(path)


def collect():
    """Return [(section_label, [(slug, title, srcpath), ...]), ...]."""
    out = []

    front = []
    d = os.path.join(ROOT, "book", "front")
    for n in sorted(os.listdir(d)):
        if n.endswith(".md"):
            p = os.path.join(d, n)
            front.append(("front-" + os.path.splitext(n)[0], heading_of(p), p))
    out.append(("Front matter", front))

    for i in range(1, 6):
        d = os.path.join(ROOT, "book", "part%d" % i)
        if not os.path.isdir(d):
            continue
        items = []
        label = "Part %d" % i
        for n in sorted(os.listdir(d)):
            if not n.endswith(".md"):
                continue
            p = os.path.join(d, n)
            if n == "00-part.md":
                with io.open(p, encoding="utf-8") as f:
                    m = re.search(r'name="([^"]+)"', f.read())
                if m:
                    label = "Part %d · %s" % (i, m.group(1))
                continue
            items.append(("part%d-%s" % (i, os.path.splitext(n)[0]),
                          heading_of(p), p))
        out.append((label, items))

    back = []
    d = os.path.join(ROOT, "book", "back")
    for n in sorted(os.listdir(d)):
        if n.endswith(".md"):
            p = os.path.join(d, n)
            back.append(("back-" + os.path.splitext(n)[0], heading_of(p), p))
    out.append(("Back matter", back))

    gram = []
    d = os.path.join(ROOT, "grammar")
    for n in sorted(os.listdir(d)):
        if n.endswith(".md"):
            p = os.path.join(d, n)
            gram.append(("grammar-" + os.path.splitext(n)[0], heading_of(p), p))
    out.append(("Reference grammar", gram))

    return out


def nav_html(groups, current=None):
    parts = ['<nav class="toc">']
    parts.append('<h2>Contents</h2><ol><li><a href="index.html"%s>Home</a></li></ol>'
                 % (' class="current"' if current is None else ""))
    n = 0
    for label, items in groups:
        if not items:
            continue
        parts.append("<h2>%s</h2><ol>" % label)
        for slug, title, _ in items:
            num = ""
            m = re.search(r"lesson-(\d+)$", slug)
            if m:
                n = int(m.group(1))
                num = '<span class="num">%d</span>' % n
            cur = ' class="current"' if slug == current else ""
            parts.append('<li><a href="%s.html"%s>%s%s</a></li>'
                         % (slug, cur, num, title))
        parts.append("</ol>")
    parts.append("</nav>")
    return "\n".join(parts)


PAGE = u"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · {sitetitle}</title>
<meta name="description" content="{sitetitle}. {subtitle}.">
<link rel="stylesheet" href="style.css">
</head>
<body class="{bodyclass}">
<header class="site"><div class="inner">
  <a class="brand" href="index.html">{sitetitle}</a>
  <div class="tools">
    <button id="edition" type="button" title="Show or hide the answer keys">Show answers</button>
    <button id="theme" type="button" title="Switch between light and dark">Theme</button>
  </div>
</div></header>
<div class="wrap">
{nav}
<main>
{body}
{pager}
</main>
</div>
<footer class="site"><div class="inner">
  <p>{sitetitle} · {subtitle}. Text licensed CC BY-NC-SA 4.0;
     build system licensed MIT. Greek set in Gentium Book Plus (SIL OFL).</p>
</div></footer>
<script>
(function () {{
  var root = document.documentElement, body = document.body;
  try {{
    var t = localStorage.getItem("gc-theme");
    if (t) root.setAttribute("data-theme", t);
    if (localStorage.getItem("gc-edition") === "teacher")
      body.classList.remove("student-edition");
  }} catch (e) {{}}
  var tb = document.getElementById("theme");
  if (tb) tb.addEventListener("click", function () {{
    var dark = getComputedStyle(body).backgroundColor;
    var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try {{ localStorage.setItem("gc-theme", next); }} catch (e) {{}}
  }});
  var eb = document.getElementById("edition");
  function label() {{
    if (eb) eb.textContent = body.classList.contains("student-edition")
      ? "Show answers" : "Hide answers";
  }}
  label();
  if (eb) eb.addEventListener("click", function () {{
    body.classList.toggle("student-edition");
    try {{
      localStorage.setItem("gc-edition",
        body.classList.contains("student-edition") ? "student" : "teacher");
    }} catch (e) {{}}
    label();
  }});
}})();
</script>
</body>
</html>
"""


def pager(flat, idx):
    prev_ = '<a href="%s.html">&larr; %s</a>' % (flat[idx-1][0], flat[idx-1][1]) if idx > 0 else ""
    next_ = '<a href="%s.html">%s &rarr;</a>' % (flat[idx+1][0], flat[idx+1][1]) if idx < len(flat)-1 else ""
    return '<div class="pager">%s<div class="spacer"></div>%s</div>' % (prev_, next_)


def landing(groups):
    lessons = []
    for label, items in groups:
        if label.startswith("Part"):
            lessons.extend(items)
    pdfs = []
    for name, desc in (("greek-classroom.pdf", "the student edition"),
                       ("greek-classroom-teacher.pdf", "the teacher's edition, with answer keys"),
                       ("greek-grammar.pdf", "the reference grammar")):
        if os.path.exists(os.path.join(BUILD, name)):
            pdfs.append('<li><a href="%s">%s</a> &mdash; %s</li>' % (name, name, desc))
    pdf_html = ("<ul>" + "".join(pdfs) + "</ul>") if pdfs else \
        "<p>Run <code>make pdf teacher grammar</code> to build the PDFs.</p>"

    body = u"""
<div class="hero">
  <h1>{t}</h1>
  <p class="sub">{s}</p>
  <p class="greek">ΤΟ ΔΙΔΑΣΚΑΛΕΙΟΝ</p>
</div>

<p>Rome, autumn of AD 400. Eight Latin-speaking children in a household
school on the Caelian Hill are made to study Greek by a grammarian from
Antioch. They find the language old-fashioned, the declensions
infuriating, and their teacher's expectations unreasonable. Over thirty
lessons they discover that the ancient authors are not dusty authorities
but people who asked questions that still matter.</p>

<p>This is a complete Classical Attic course for grades 7&ndash;9, built as a
continuing story. Each lesson advances the pupils' Greek and their
relationships with one another. Their classroom mischief provides the
comedy; the texts themselves provide the substance.</p>

<div class="cards">
  <div class="card">
    <h3>Start here</h3>
    <p>The course in five movements a lesson, and what it assumes you know.</p>
    <p><a href="front-01-preface.html">Preface</a> &middot;
       <a href="front-02-to-students.html">To the student</a> &middot;
       <a href="front-05-scope-and-sequence.html">Scope and sequence</a></p>
  </div>
  <div class="card">
    <h3>Lesson 1</h3>
    <p>Marcus declares that Greek letters are Latin letters that have gone
       wrong. Theodoros writes ΑΘΗΝΑ on the board.</p>
    <p><a href="part1-01-lesson-01.html">The Unwelcome Tablet &rarr;</a></p>
  </div>
  <div class="card">
    <h3>The grammar</h3>
    <p>A reference volume sized to a beginning reader, cross-linked to every
       lesson in both directions.</p>
    <p><a href="grammar-00-intro.html">Reference grammar &rarr;</a></p>
  </div>
</div>

<h2>Download</h2>
{p}

<h2>The thirty lessons</h2>
<ol>
{l}
</ol>

<h2>How the two editions differ</h2>
<p>The student edition contains no answers. The teacher's edition contains
them all, inline after each exercise. Both are generated from the same
source files, so they cannot drift apart. On this site you can toggle the
answer keys with the button in the top right.</p>
""".format(t=TITLE, s=SUBTITLE, p=pdf_html,
           l="\n".join('<li><a href="%s.html">%s</a></li>' % (s, t)
                       for s, t, _ in lessons))
    return body


def convert(src):
    return sh([PANDOC, "--from=" + FROM, "--to=html5",
               "--lua-filter=" + FILTER,
               "--metadata=edition:teacher",
               "--no-highlight", src])


def main():
    if os.path.isdir(SITE):
        shutil.rmtree(SITE)
    os.makedirs(os.path.join(SITE, "fonts"))

    shutil.copy(os.path.join(ROOT, "assets", "css", "site.css"),
                os.path.join(SITE, "style.css"))

    # fonts: woff2 if we can make it, ttf otherwise
    made_woff = 0
    for f in ("GentiumBookPlus-Regular", "GentiumBookPlus-Bold",
              "GentiumBookPlus-Italic"):
        ttf = os.path.join(ROOT, "assets", "fonts", f + ".ttf")
        if not os.path.exists(ttf):
            continue
        out2 = os.path.join(SITE, "fonts", f + ".woff2")
        try:
            from fontTools.ttLib import TTFont
            font = TTFont(ttf)
            font.flavor = "woff2"
            font.save(out2)
            made_woff += 1
        except Exception:
            shutil.copy(ttf, os.path.join(SITE, "fonts", f + ".ttf"))
    print("  fonts: %d woff2, %d ttf"
          % (made_woff, len(os.listdir(os.path.join(SITE, "fonts"))) - made_woff))

    for name in ("greek-classroom.pdf", "greek-classroom-teacher.pdf",
                 "greek-grammar.pdf"):
        p = os.path.join(BUILD, name)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(SITE, name))

    groups = collect()
    flat = [(s, t, p) for _, items in groups for s, t, p in items]

    io.open(os.path.join(SITE, "index.html"), "w", encoding="utf-8").write(
        PAGE.format(title="Home", sitetitle=TITLE, subtitle=SUBTITLE,
                    bodyclass="student-edition", nav=nav_html(groups),
                    body=landing(groups), pager=""))

    for i, (slug, title, src) in enumerate(flat):
        io.open(os.path.join(SITE, slug + ".html"), "w", encoding="utf-8").write(
            PAGE.format(title=title, sitetitle=TITLE, subtitle=SUBTITLE,
                        bodyclass="student-edition",
                        nav=nav_html(groups, slug),
                        body=convert(src), pager=pager(flat, i)))

    io.open(os.path.join(SITE, ".nojekyll"), "w", encoding="utf-8").write("")
    print("  %d pages -> %s" % (len(flat) + 1, os.path.relpath(SITE, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
