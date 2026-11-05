#!/bin/bash
set -euo pipefail

epub_file="${1:?An EPUB file is required}"
ebook-convert --version
wine --version

for ext in azw3 docx mobi pdf txt; do
    echo "Converting to $ext"
    ebook-convert "$epub_file" "${epub_file%.epub}.$ext"
    test -s "${epub_file%.epub}.$ext"
done

echo "Converting to KFX"
WINEDEBUG=-all calibre-debug -r 'KFX Output' -- "$epub_file" "${epub_file%.epub}.kfx" --logs
test -s "${epub_file%.epub}.kfx"
WINEDEBUG=-all calibre-debug -r 'KFX Input' -- "${epub_file%.epub}.kfx" "${epub_file%.epub}-roundtrip.epub"
test -s "${epub_file%.epub}-roundtrip.epub"
7z t "${epub_file%.epub}-roundtrip.epub"
