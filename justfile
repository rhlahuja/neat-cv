target := "local"
docs := "cv letter"
svg_specs := "cv:1 cv:2 cv:3 letter:1"

default: compile-pdf

# Compile all documents to PDF
compile-pdf:
    @for doc in {{ docs }}; do \
        just compile-pdf-doc "$doc"; \
    done

# Compile specific document to PDF
compile-pdf-doc doc:
    @if [ "{{ target }}" = "published" ]; then \
        just _compile template/{{ doc }}.typ template/{{ doc }}.pdf; \
    else \
        just _compile-local {{ doc }} pdf; \
    fi

# Compile all documents to SVG (for README previews)
compile-svg:
    @for spec in {{ svg_specs }}; do \
        doc="${spec%%:*}"; \
        page="${spec##*:}"; \
        just compile-svg-doc "$doc" "$page"; \
    done

# Compile specific document page to SVG
compile-svg-doc doc page="1":
    #!/usr/bin/env bash
    if [ "{{ doc }}" = "letter" ]; then
        output="assets/{{ doc }}.svg"
    else
        output="assets/{{ doc }}_p{{ page }}.svg"
    fi
    if [ "{{ target }}" = "published" ]; then
        just _compile-svg template/{{ doc }}.typ $output {{ page }}
    else
        just _compile-local {{ doc }} svg {{ page }} $output
    fi

# Compile thumbnail WebP (for typst.toml — only needs updating on major visual changes)
compile-thumbnail:
    @if [ "{{ target }}" = "published" ]; then \
        just _compile-thumbnail template/cv.typ assets/thumbnail.webp; \
    else \
        just _compile-local cv thumbnail 1 assets/thumbnail.webp; \
    fi

# Clean generated files
clean:
    @rm -f template/*.tmp.typ template/*.pdf assets/cv_p*.svg assets/letter.svg

# Format source files
format:
    @files=""; \
    for doc in {{ docs }}; do \
        files="$files template/$doc.typ"; \
    done; \
    typstyle -i lib.typ $files

# Compile with local library (for development)
_compile-local doc format page="" output="":
    #!/usr/bin/env bash
    tmp="template/{{ doc }}.tmp.typ"
    sed 's|#import "@preview/neat-cv:[0-9.]*"|#import "../lib.typ"|' template/{{ doc }}.typ > "$tmp"
    if [ "{{ format }}" = "pdf" ]; then
        just _compile "$tmp" template/{{ doc }}.pdf
    elif [ "{{ format }}" = "svg" ]; then
        just _compile-svg "$tmp" {{ output }} {{ page }}
    elif [ "{{ format }}" = "thumbnail" ]; then
        just _compile-thumbnail "$tmp" {{ output }}
    fi
    rm "$tmp"

# Compile to PDF
_compile input output:
    @typst compile --root . {{ input }} {{ output }}

# Compile to SVG with a thin black border rect
_compile-svg input output page:
    #!/usr/bin/env bash
    typst compile --root . --format svg --pages {{ page }} {{ input }} {{ output }}
    python3 -c "
    import re, sys
    svg = sys.stdin.read()
    m = re.search(r'width=\"([0-9.]+)pt\" height=\"([0-9.]+)pt\"', svg)
    w, h = float(m.group(1)), float(m.group(2))
    border = f'<rect x=\"0.5\" y=\"0.5\" width=\"{w-1}\" height=\"{h-1}\" fill=\"none\" stroke=\"black\" stroke-width=\"1\"/>'
    print(svg.replace('</svg>', border + '</svg>'))
    " < {{ output }} > {{ output }}.tmp && mv {{ output }}.tmp {{ output }}

# Compile to WebP (for thumbnail only): export page 1 as PNG, convert to WebP, clean up
_compile-thumbnail input output:
    #!/usr/bin/env bash
    tmp_png="{{ output }}.tmp.png"
    typst compile --root . --format png --pages 1 {{ input }} "$tmp_png"
    magick "$tmp_png" {{ output }}
    rm "$tmp_png"
