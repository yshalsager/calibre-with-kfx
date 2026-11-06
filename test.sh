#!/bin/bash
set -euo pipefail

epub_file="${1:?An EPUB file is required}"
variant="${2:-full}"
backends=(kfxgen boko)
case "$variant" in
    full)
        wine --version
        backends=(previewer kfxgen boko)
        ;;
    slim)
        if command -v wine || command -v python3 || [[ -d /opt/kp4 || -d /home/calibre/.wine ]]; then
            echo 'The slim image unexpectedly includes Wine, Previewer, or standalone Python' >&2
            exit 1
        fi
        [[ "${KFX_BACKEND:-}" == kfxgen ]]
        ;;
    *) echo 'Variant must be full or slim' >&2; exit 1 ;;
esac
ebook-convert --version
boko --version
calibre-debug -c 'import sys; from calibre.customize.ui import plugin_for_output_format; sys.exit(0 if plugin_for_output_format("kfx").name == "kfxgen" else "Automatic KFX selection must use kfxgen")'

for ext in azw3 docx epub fb2 htmlz kepub mobi pdf rtf txt txtz; do
    echo "Converting to $ext"
    output_file="${epub_file%.epub}-converted.$ext"
    /sbin/entrypoint.sh "$epub_file" "$output_file"
    test -s "$output_file"
done
ebook-polish --compress-images "$epub_file" "${epub_file%.epub}-polished.epub"
ebook-meta "${epub_file%.epub}-polished.epub" --title 'Conversion test'
ebook-convert "${epub_file%.epub}-converted.pdf" "${epub_file%.epub}-from-pdf.epub"
test -s "${epub_file%.epub}-from-pdf.epub"

for backend in "${backends[@]}"; do
    echo "Converting to KFX using $backend"
    kfx_file="${epub_file%.epub}-$backend.kfx"
    roundtrip_file="${epub_file%.epub}-$backend-roundtrip.epub"
    if [[ "$backend" == previewer ]]; then
        /sbin/entrypoint.sh "$epub_file" "${kfx_file%.kfx}.KfX" --logs
        mv "${kfx_file%.kfx}.KfX" "$kfx_file"
    elif [[ "$backend" == boko ]]; then
        KFX_BACKEND=boko /sbin/entrypoint.sh "$epub_file" "${kfx_file%.kfx}.KfX"
        mv "${kfx_file%.kfx}.KfX" "$kfx_file"
    elif [[ "$variant" == slim ]]; then
        /sbin/entrypoint.sh "$epub_file" "$kfx_file" --kfxgen-disable-approximate-pages
    else
        KFX_BACKEND=kfxgen /sbin/entrypoint.sh "$epub_file" "$kfx_file" --kfxgen-disable-approximate-pages
    fi
    test -s "$kfx_file"
    WINEDEBUG=-all calibre-debug -r 'KFX Input' -- "$kfx_file" "$roundtrip_file"
    test -s "$roundtrip_file"
    calibre-debug -c 'from zipfile import ZipFile; import sys; sys.exit(ZipFile(sys.argv[1]).testzip())' "$roundtrip_file"
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

if KFX_BACKEND=boko /sbin/entrypoint.sh "$epub_file" "${epub_file%.epub}-boko-invalid-options.kfx" --pages 0 \
    > "${epub_file%.epub}-boko-invalid-options.log" 2>&1; then
    echo 'Boko accepted a Previewer-only option' >&2
    exit 1
fi
grep -F "unexpected argument '--pages'" "${epub_file%.epub}-boko-invalid-options.log"

if KFX_BACKEND=boko /sbin/entrypoint.sh "${epub_file%.epub}-converted.pdf" "${epub_file%.epub}-boko-unsupported.kfx" \
    > "${epub_file%.epub}-boko-unsupported.log" 2>&1; then
    echo 'Boko accepted an unsupported input format' >&2
    exit 1
fi
grep -F 'unsupported format:' "${epub_file%.epub}-boko-unsupported.log"
KFX_BACKEND=boko /sbin/entrypoint.sh "$epub_file" "${epub_file%.epub}-boko-non-kfx.docx"
test -s "${epub_file%.epub}-boko-non-kfx.docx"
boko convert "${epub_file%.epub}-boko.kfx" "${epub_file%.epub}-boko-direct.epub"
test -s "${epub_file%.epub}-boko-direct.epub"

for input_file in "${epub_file%.epub}-converted.azw3" "${epub_file%.epub}-converted.mobi"; do
    kfx_file="${epub_file%.epub}-from-${input_file##*.}-boko.kfx"
    roundtrip_file="${kfx_file%.kfx}-roundtrip.epub"
    KFX_BACKEND=boko /sbin/entrypoint.sh "$input_file" "$kfx_file" --quiet
    test -s "$kfx_file"
    calibre-debug -r 'KFX Input' -- "$kfx_file" "$roundtrip_file"
    test -s "$roundtrip_file"
    calibre-debug -c 'from zipfile import ZipFile; import sys; sys.exit(ZipFile(sys.argv[1]).testzip())' "$roundtrip_file"
done

if [[ "$variant" == slim ]]; then
    if KFX_BACKEND=previewer /sbin/entrypoint.sh "$epub_file" "${epub_file%.epub}-unavailable.kfx" \
        > "${epub_file%.epub}-unavailable.log" 2>&1; then
        echo 'The slim image accepted the Previewer backend' >&2
        exit 1
    fi
    grep -F 'Previewer is unavailable in this image' "${epub_file%.epub}-unavailable.log"
fi
calibre-debug /app/tests/kfxgen_rtl.py
