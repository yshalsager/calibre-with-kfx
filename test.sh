#!/bin/bash
set -e

epub_file="$1"

for ext in azw3 docx mobi pdf txt; do
    echo "Converting to $ext"
    ebook-convert $epub_file "${epub_file%.epub}.$ext"
done

echo "Converting to KFX"
calibre-debug -r "KFX Output" -- $epub_file
calibre-debug -r "KFX Input" -- "${epub_file%.epub}.kfx" "c-${epub_file%.epub}.kfx"


# docker run --rm -v "$(pwd):/app:rw" --entrypoint="bash" yshalsager/calibre-with-kfx -c "./test.sh trees.epub"