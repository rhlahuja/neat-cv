target := "local"
docs := "cv letter"
webp_specs := "cv:1 cv:2 cv:3 letter:1"

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

# Compile all documents to WebP (for README previews and thumbnail)
compile-webp:
    @for spec in {{ webp_specs }}; do \
        doc="${spec%%:*}"; \
        page="${spec##*:}"; \
        just compile-webp-doc "$doc" "$page"; \
    done

# Compile specific document page to WebP
compile-webp-doc doc page="1":
    #!/usr/bin/env bash
    if [ "{{ doc }}" = "letter" ]; then
        output="assets/{{ doc }}.webp"
    else
        output="assets/{{ doc }}_p{{ page }}.webp"
    fi
    if [ "{{ target }}" = "published" ]; then
        just _compile-webp template/{{ doc }}.typ $output {{ page }}
    else
        just _compile-local {{ doc }} webp {{ page }} $output
    fi

# Compile with local library (for development)
_compile-local doc format page="" output="":
    #!/usr/bin/env bash
    tmp="template/{{ doc }}.tmp.typ"
    sed 's|#import "@preview/neat-cv:[0-9.]*"|#import "../lib.typ"|' template/{{ doc }}.typ > "$tmp"
    if [ "{{ format }}" = "pdf" ]; then
        just _compile "$tmp" template/{{ doc }}.pdf
    elif [ "{{ format }}" = "webp" ]; then
        just _compile-webp "$tmp" {{ output }} {{ page }}
    fi
    rm "$tmp"

# Compile to PDF
_compile input output:
    @typst compile --root . {{ input }} {{ output }}

# Compile to WebP: export as PNG, add border, convert to WebP, clean up
_compile-webp input output page:
    #!/usr/bin/env bash
    tmp_png="{{ output }}.tmp.png"
    typst compile --root . --format png --pages {{ page }} {{ input }} "$tmp_png"
    magick "$tmp_png" -bordercolor black -border 1 {{ output }}
    rm "$tmp_png"

# Clean generated files
clean:
    @rm -f template/*.tmp.typ template/*.pdf assets/cv_p*.webp assets/letter.webp

# Format source files
format:
    @files=""; \
    for doc in {{ docs }}; do \
        files="$files template/$doc.typ"; \
    done; \
    typstyle -i lib.typ $files
