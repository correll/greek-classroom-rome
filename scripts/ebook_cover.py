#!/usr/bin/env python3
"""
ebook_cover.py - the Kindle cover: 1600 x 2560 px JPEG (KDP's ideal size,
1.6:1), in the same design as the front of the Lulu wrap cover.

Typeset with XeLaTeX at 6.25 x 10 in, then rasterised at 256 dpi.

Usage: ebook_cover.py OUT.jpg [--subtitle TEXT]
"""
import argparse
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tex(subtitle):
    fonts = os.path.join(ROOT, "assets", "fonts") + "/"
    cover = os.path.join(ROOT, "assets", "illustrations", "cover.jpg")
    sub = (r"{\color{cream}\Large\itshape %s\par}\vspace{12pt}" % subtitle
           if subtitle else "")
    return r"""\documentclass{article}
\usepackage[paperwidth=6.25in,paperheight=10in,margin=0in]{geometry}
\usepackage{fontspec}
\setmainfont{GentiumBookPlus}[Path=%(fonts)s, Extension=.ttf,
  UprightFont=*-Regular, ItalicFont=*-Italic]
\newfontfamily\didot{GFSDidot-Regular}[Path=%(fonts)s, Extension=.ttf]
\usepackage{xcolor}
\definecolor{ink}{HTML}{1F3A5F}
\definecolor{gold}{HTML}{C9A45C}
\definecolor{cream}{HTML}{F4EEDF}
\usepackage{graphicx}
\usepackage{tikz}
\pagestyle{empty}
\setlength{\parindent}{0pt}
\begin{document}
\begin{tikzpicture}[remember picture, overlay, x=1in, y=1in,
                    shift={(current page.south west)}]
  \fill[ink] (0,0) rectangle (6.25,10);
  \node[anchor=north, text width=5.4in, align=center] at (3.125, 9.35) {%%
    {\color{gold}\rule{0.6\linewidth}{0.9pt}}\\[24pt]
    {\didot\color{cream}\fontsize{50}{56}\selectfont Schola Graeca\par}
    \vspace{14pt}
    %(sub)s
    {\color{gold}\rule{0.6\linewidth}{0.9pt}}\\[26pt]
    {\didot\color{gold}\fontsize{33}{39}\selectfont ΤΟ ΔΙΔΑΣΚΑΛΕΙΟΝ\par}};
  \node[anchor=center] at (3.125, 4.0)
    {\tikz{\node[inner sep=0.08in, fill=cream, draw=gold, line width=0.9pt]
      {\includegraphics[width=5.25in]{%(cover)s}};}};
  \node[anchor=south] at (3.125, 0.55)
    {\color{cream}\fontsize{22}{26}\selectfont Nikolaus Correll};
\end{tikzpicture}
\end{document}
""" % dict(fonts=fonts, cover=cover, sub=sub)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--subtitle", default="A Classical Greek course")
    a = ap.parse_args()
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, "cover.tex"), "w", encoding="utf-8") as f:
            f.write(tex(a.subtitle))
        for _ in range(2):
            r = subprocess.run(["xelatex", "-interaction=nonstopmode",
                                "-halt-on-error", "cover.tex"],
                               cwd=d, capture_output=True, text=True)
            if r.returncode != 0:
                sys.stdout.write(r.stdout[-3000:])
                sys.exit("xelatex failed on the ebook cover")
        subprocess.run(["pdftoppm", "-jpeg", "-jpegopt", "quality=92",
                        "-r", "256", "-singlefile", "cover.pdf", "cover"],
                       cwd=d, check=True)
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        with open(os.path.join(d, "cover.jpg"), "rb") as f, open(a.out, "wb") as g:
            g.write(f.read())
    print("  -> %s" % a.out)


if __name__ == "__main__":
    main()
