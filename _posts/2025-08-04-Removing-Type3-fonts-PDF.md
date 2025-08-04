---
layout: post
title:  "Removing Type 3 fonts in PDFs"
description: "Removing Type 3 fonts in PDFs"
date:   2025-08-04 22:02:11
categories: formatting
tags: [pdf]
comments: true
---

* TOC
{:toc}

Generating a PDF to be published in scientific venues imposes a number of formatting constraints. This entry deals with those related to Type 3 fonts.

<!--more-->

Scientific editors configure the publishing platform to reject an uploaded paper if it does not meet a set of hard constraints.
For instance, [EDAS](https://edas.info/doc/papers.html), a well-known platform used by IEEE conferences, will fail based on invalid margins, enabled [PDF links](https://edas.info/faq221) and [bookmarks](https://edas.info/faq115), [missing embedded fonts](https://edas.info/faq109).
However, some soft constraints will be shown as warnings, yet be equally important.

This is the case of Type 3 fonts. These are "bitmapped fonts" which do not scale well for printing, and are thus [not allowed by IEEE](https://ras.papercept.net/conferences/support/general.php#type3).

To identify whether these fonts are in a PDF, it can be opened in the "Properties" tab of PDF viewer, such as Adobe Acrobat, Evince or Okular (the two latter for GNOME or KDE environments, respectively).

It can be also read from the terminal, e.g. [using the `pdffonts` command](https://unix.stackexchange.com/a/335815/90930) in Unix.

```bash
$ pdffonts ${pdf_name}.pdf
name                                 type              encoding         emb sub uni object ID
------------------------------------ ----------------- ---------------- --- --- --- ---------
XIEDYY+CMSY10                        Type 1            Builtin          yes yes yes     31  0
JDBIHO+NimbusRomNo9L-Medi            Type 1            Custom           yes yes yes    225  0
...
AAAAAA+Arimo                         CID TrueType      Identity-H       yes yes yes     98  0
BMQQDV+DejaVuSans                    Type 3            Custom           yes yes no      24  0
BMQQDV+DejaVuSans                    Type 3            Custom           yes yes no      66  0
```

The latter provides more details on the number and ID of specific objects within the PDF that bring each type of font.

### Coding the solution

[TeX StackExchange](https://tex.stackexchange.com/questions/437567/get-rid-of-type-3-fonts-in-pdf-for-manuscript) points to some troubleshooting hints to find the culprit that involves Type 3 fonts, i.e. whether this is brought by an embedded PDF file or by the main paper. [Compiling in draft mode](https://tex.stackexchange.com/a/437785/52085) is an option to identify this.

Now, if an image is bringing the dreaded Type 3 fonts, and this image was created with Matplotlib (a well-known plot generation library for Python); [Jamie Oaks proposes a solution](https://phyletica.org/matplotlib-fonts/) to instruct Matplotlib to avoid such fonts, which are otherwise added by default.

```python
import matplotlib
matplotlib.rcParams["pdf.fonttype"] = 42
matplotlib.rcParams["ps.fonttype"] = 42
```

This is the clean, proper approach.

### Post-processing the PDFs

Another approach is to re-generate the problematic PDFs, [as exposed by Martin Kiefer](https://blog.boxm.de/2023/01/28/getting-rid-of-type-3-fonts-in-pdfs/); who uses Apple's OS X document preview to print the PDF and, in the process, replacing Type 3 to TrueType fonts.

A more generic approach to post-process these is to use open-source, cross-platform software.
The InkScape vector image editor allows to do this by:

1. Open the file with the default settings, i.e. checking the following boxes:
  * "Import settings: Internal import"
  * "Replace PDF fonts by closest-named installed fonts"
  * "Embed images"
1. Go to "File" > "Save as" using the default settings.

When checking again the PDF properties on the regenerated file, the previous "Type 3" fonts should be now replaced by "TrueType" fonts.

```bash
$ pdffonts ${pdf_name}.pdf
name                                 type              encoding         emb sub uni object ID
------------------------------------ ----------------- ---------------- --- --- --- ---------
XIEDYY+CMSY10                        Type 1            Builtin          yes yes yes    183  0
JDBIHO+NimbusRomNo9L-Medi            Type 1            Custom           yes yes yes    154  0
...
AAAAAA+Arimo                         CID TrueType      Identity-H       yes yes yes     43  0
QGQCCE+DejaVuSans                    TrueType          WinAnsi          yes yes yes     94  0
IPHYWX+DejaVuSans                    TrueType          WinAnsi          yes yes yes    112  0
```

At this point, the publisher's platform (e.g. EDAS) should no longer throw any warning and the paper should be compatible in this front.
