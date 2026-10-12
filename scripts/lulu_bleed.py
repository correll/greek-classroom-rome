#!/usr/bin/env python3
"""
lulu_bleed.py - give an interior PDF the 0.125 in bleed Lulu asks for.

Lulu wants interior files at trim size plus 0.125 in on every side
(7 x 10 in becomes 7.25 x 10.25 in), and otherwise adds its own white
margin and warns. Nothing in this book runs to the edge, so the bleed is
plain white: each page is enlarged by 9 pt all round with its content
moved in by the same amount, so the type sits exactly where it did
relative to the trim. TrimBox and BleedBox are set so that any checker
can see where the cut falls.

Links are dropped: they do nothing on paper, and leaving them would mean
moving every one.

Usage: lulu_bleed.py IN.pdf OUT.pdf
"""
import sys

import pikepdf

BLEED = 9.0   # 0.125 in, in points


def main(src, dst):
    with pikepdf.open(src) as pdf:
        for page in pdf.pages:
            x0, y0, x1, y1 = [float(v) for v in page.mediabox]
            w, h = x1 - x0, y1 - y0
            page.contents_add(pikepdf.Stream(
                pdf, b"q 1 0 0 1 %g %g cm\n" % (BLEED - x0, BLEED - y0)),
                prepend=True)
            page.contents_add(pikepdf.Stream(pdf, b"\nQ\n"))
            full = pikepdf.Array([0, 0, w + 2 * BLEED, h + 2 * BLEED])
            page.obj.MediaBox = full
            page.obj.BleedBox = full
            page.obj.TrimBox = pikepdf.Array(
                [BLEED, BLEED, w + BLEED, h + BLEED])
            for key in ("/CropBox", "/ArtBox", "/Annots"):
                if key in page.obj:
                    del page.obj[key]
        pdf.save(dst)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
