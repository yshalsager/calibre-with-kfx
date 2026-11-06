#!/bin/bash
set -euo pipefail

epub_file="${1:?An EPUB file is required}"
ebook-convert --version
wine --version

for ext in azw3 docx mobi pdf txt; do
    echo "Converting to $ext"
    /sbin/entrypoint.sh "$epub_file" "${epub_file%.epub}.$ext"
    test -s "${epub_file%.epub}.$ext"
done

for backend in previewer kfxgen; do
    echo "Converting to KFX using $backend"
    kfx_file="${epub_file%.epub}-$backend.kfx"
    roundtrip_file="${epub_file%.epub}-$backend-roundtrip.epub"
    if [[ "$backend" == previewer ]]; then
        env -u KFX_BACKEND WINEDEBUG=-all /sbin/entrypoint.sh "$epub_file" "${kfx_file%.kfx}.KfX" --logs
        mv "${kfx_file%.kfx}.KfX" "$kfx_file"
    else
        KFX_BACKEND=kfxgen /sbin/entrypoint.sh "$epub_file" "$kfx_file" --kfxgen-disable-approximate-pages
    fi
    test -s "$kfx_file"

    WINEDEBUG=-all calibre-debug -r 'KFX Input' -- "$kfx_file" "$roundtrip_file"
    test -s "$roundtrip_file"
    7z t "$roundtrip_file"
done

if KFX_BACKEND=invalid /sbin/entrypoint.sh "$epub_file" "${epub_file%.epub}-invalid.KFX" \
    > "${epub_file%.epub}-invalid.log" 2>&1; then
    echo 'An invalid KFX backend was accepted' >&2
    exit 1
fi
grep -F 'Invalid KFX_BACKEND: invalid' "${epub_file%.epub}-invalid.log"

if KFX_BACKEND=kfxgen /sbin/entrypoint.sh "$epub_file" "${epub_file%.epub}-invalid-options.kfx" --pages 0 \
    > "${epub_file%.epub}-invalid-options.log" 2>&1; then
    echo 'kfxgen accepted a Previewer-only option' >&2
    exit 1
fi
grep -F 'no such option: --pages' "${epub_file%.epub}-invalid-options.log"
