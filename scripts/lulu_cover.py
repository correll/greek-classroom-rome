#!/usr/bin/env python3
"""
lulu_cover.py - the one-piece wrap cover for a Lulu hardcover (casewrap).

Lulu prints the cover of a casewrap hardcover as a single sheet: back panel,
spine, front panel, with a wrap margin all round that folds over the boards.
The geometry below is Lulu's cover template for a 7 x 10 in interior
(docs: help.lulu.com, "How is spine width calculated?"):

    panel (board) size   7.25 x 10.5 in
    wrap, all round      0.625 in
    safety margin        0.625 in inside each panel edge
    barcode area         3.622 x 1.26 in, back panel, bottom, against the
                         spine-side safety line (left free for Lulu's ISBN)
    spine width          from the interior's page count (table below)

Usage: lulu_cover.py INTERIOR.pdf OUT.pdf [--subtitle TEXT] [--spine INCHES]

The interior's page count is read with pdfinfo. If Lulu's own template for
the upload gives a different spine width, pass it with --spine.
"""
import argparse
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PANEL_W, PANEL_H = 7.25, 10.5
WRAP = 0.625
SAFE = 0.625
BARCODE_W, BARCODE_H = 3.622, 1.26

# Lulu hardcover casewrap: (last page count in the band, spine width in inches)
SPINE_TABLE = [
    (84, 0.25), (140, 0.5), (168, 0.625), (194, 0.6875), (222, 0.75),
    (250, 0.8125), (278, 0.875), (306, 0.9375), (334, 1.0), (360, 1.0625),
    (388, 1.125), (416, 1.1875), (444, 1.25), (472, 1.3125), (500, 1.375),
    (528, 1.4375), (556, 1.5), (582, 1.5625), (610, 1.625), (638, 1.6875),
    (666, 1.75), (694, 1.8125), (722, 1.875), (750, 1.9375), (778, 2.0),
    (800, 2.0625),
]

BLURB = r"""Rome, autumn of AD 400. Eight Latin-speaking children in a household
school on the Caelian Hill are made to study Greek by a grammarian from
Antioch. They find the language old-fashioned, the declensions infuriating,
and their teacher's expectations unreasonable. Over thirty-six lessons they
discover that the ancient authors are not dusty authorities but people who
asked questions that still matter.

Greek writes the grammar on the outside of every word, so a student can
point at the evidence for a reading and defend it. The course's recurring
question, \textit{what in the sentence tells you that?}, is the whole
transferable skill."""


def page_count(pdf):
    out = subprocess.run(["pdfinfo", pdf], capture_output=True, text=True,
                         check=True).stdout
    for line in out.splitlines():
        if line.startswith("Pages:"):
            return int(line.split()[1])
    sys.exit("pdfinfo gave no page count for " + pdf)


def spine_for(pages):
    if pages < 24:
        sys.exit("Lulu casewrap needs at least 24 pages; this has %d" % pages)
    for last, width in SPINE_TABLE:
        if pages <= last:
            return width
    sys.exit("more than 800 pages: outside Lulu's casewrap table")


def tex(spine, subtitle):
    W = 2 * WRAP + 2 * PANEL_W + spine
    H = 2 * WRAP + PANEL_H
    fonts = os.path.join(ROOT, "assets", "fonts") + "/"
    cover = os.path.join(ROOT, "assets", "illustrations", "cover.jpg")
    cast = os.path.join(ROOT, "assets", "illustrations", "character-sheet.jpg")
    # x positions (inches from the left edge of the sheet)
    back_l = WRAP
    back_r = WRAP + PANEL_W
    front_l = back_r + spine
    front_r = front_l + PANEL_W
    bottom = WRAP
    top = WRAP + PANEL_H
    safe_w = PANEL_W - 2 * SAFE
    sub = (r"{\color{cream}\large\itshape %s\par}\vspace{10pt}" % subtitle
           if subtitle else "")
    return r"""\documentclass{article}
\usepackage[paperwidth=%(W).4fin,paperheight=%(H).4fin,margin=0in]{geometry}
\usepackage{fontspec}
\setmainfont{GentiumBookPlus}[Path=%(fonts)s, Extension=.ttf,
  UprightFont=*-Regular, BoldFont=*-Bold, ItalicFont=*-Italic,
  BoldItalicFont=*-BoldItalic, Numbers=OldStyle]
\newfontfamily\didot{GFSDidot-Regular}[Path=%(fonts)s, Extension=.ttf]
\usepackage{xcolor}
\definecolor{ink}{HTML}{1F3A5F}
\definecolor{gold}{HTML}{C9A45C}
\definecolor{cream}{HTML}{F4EEDF}
\usepackage{graphicx}
\usepackage{tikz}
\pagestyle{empty}
\frenchspacing
\setlength{\parindent}{0pt}
%% a picture on a cream mat with a thin gold rule, like a plate in a book
\newcommand{\plate}[2]{%%
  \tikz{\node[inner sep=0.09in, fill=cream, draw=gold, line width=0.8pt]
    {\includegraphics[width=#2]{#1}};}}
\begin{document}
\begin{tikzpicture}[remember picture, overlay, x=1in, y=1in,
                    shift={(current page.south west)}]
  %% background runs through the wrap, so the fold never shows white
  \fill[ink] (0,0) rectangle (%(W).4f,%(H).4f);

  %% ---- front panel ----
  \node[anchor=north, text width=%(safe_w).4fin, align=center]
    at (%(front_mid).4f, %(top_safe).4f) {%%
    {\color{gold}\rule{0.55\linewidth}{0.8pt}}\\[22pt]
    {\didot\color{cream}\fontsize{46}{52}\selectfont Schola Graeca\par}
    \vspace{12pt}
    %(sub)s
    {\color{gold}\rule{0.55\linewidth}{0.8pt}}\\[24pt]
    {\didot\color{gold}\fontsize{32}{38}\selectfont ΤΟ ΔΙΔΑΣΚΑΛΕΙΟΝ\par}};
  \node[anchor=center] at (%(front_mid).4f, %(front_plate_y).4f)
    {\plate{%(cover)s}{5.55in}};
  \node[anchor=south, text width=%(safe_w).4fin, align=center]
    at (%(front_mid).4f, %(bottom_safe).4f)
    {\color{cream}\Large Nikolaus Correll};

  %% ---- spine: reads top to bottom ----
  \node[rotate=-90, anchor=center] at (%(spine_mid).4f, %(spine_title_y).4f)
    {{\didot\color{cream}\fontsize{%(spine_pt)d}{%(spine_pt)d}\selectfont Schola Graeca}%%
     \hspace{0.35in}{\didot\color{gold}\fontsize{%(spine_gk)d}{%(spine_gk)d}\selectfont ΤΟ ΔΙΔΑΣΚΑΛΕΙΟΝ}};
  \node[rotate=-90, anchor=east] at (%(spine_mid).4f, %(spine_author_y).4f)
    {{\color{cream}\fontsize{%(spine_au)d}{%(spine_au)d}\selectfont Correll}};

  %% ---- back panel ----
  \node[anchor=north, text width=%(safe_w).4fin, align=justify]
    at (%(back_mid).4f, %(top_safe).4f) {%%
    \color{cream}\fontsize{12}{16.2}\selectfont
    \setlength{\parskip}{8pt}%(blurb)s\par};
  \node[anchor=center] at (%(back_mid).4f, %(back_plate_y).4f)
    {\plate{%(cast)s}{5.55in}};
  \node[anchor=north, text width=%(safe_w).4fin, align=center]
    at (%(back_mid).4f, %(back_caption_y).4f)
    {\color{cream}\small\itshape Theodoros, Marcus, Julia, Felix, Sabina, Quintus,
     Livia, Theodosius, Aelia\\ and the cat, who is the κύριος of all of them.};
  %% the barcode area stays empty; nothing above is allowed to reach it
\end{tikzpicture}
\end{document}
""" % dict(
        W=W, H=H, fonts=fonts, cover=cover, cast=cast, sub=sub,
        safe_w=safe_w,
        front_mid=(front_l + front_r) / 2,
        back_mid=(back_l + back_r) / 2,
        spine_mid=back_r + spine / 2,
        top_safe=top - SAFE,
        bottom_safe=bottom + SAFE,
        front_plate_y=bottom + 4.15,
        back_plate_y=bottom + 4.0,
        back_caption_y=bottom + 4.0 - 1.36,
        spine_title_y=top - 3.4,
        spine_author_y=bottom + SAFE + 0.2,
        spine_pt=min(26, int(spine * 26)),
        spine_gk=min(20, int(spine * 19)),
        spine_au=min(16, int(spine * 15)),
        blurb=BLURB,
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("interior")
    ap.add_argument("out")
    ap.add_argument("--subtitle", default="A Classical Greek course")
    ap.add_argument("--spine", type=float, default=None)
    a = ap.parse_args()

    pages = page_count(a.interior)
    spine = a.spine if a.spine else spine_for(pages)
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "cover.tex")
        with open(src, "w", encoding="utf-8") as f:
            f.write(tex(spine, a.subtitle))
        # twice: the page-anchored TikZ picture needs its position from
        # the first run
        for _ in range(2):
            r = subprocess.run(["xelatex", "-interaction=nonstopmode",
                                "-halt-on-error", "cover.tex"],
                               cwd=d, capture_output=True, text=True)
            if r.returncode != 0:
                break
        if r.returncode != 0:
            sys.stdout.write(r.stdout[-3000:])
            sys.exit("xelatex failed on the cover")
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        with open(os.path.join(d, "cover.pdf"), "rb") as f, \
                open(a.out, "wb") as g:
            g.write(f.read())
    W = 2 * WRAP + 2 * PANEL_W + spine
    print("  -> %s  (%d pages, spine %.4g in, sheet %.4g x %.4g in)"
          % (a.out, pages, spine, W, 2 * WRAP + PANEL_H))


if __name__ == "__main__":
    main()
