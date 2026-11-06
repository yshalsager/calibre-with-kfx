import os
import re
import subprocess
from pathlib import Path
from zipfile import ZipFile

from calibre_plugins.kfx_input.kfxlib import YJ_Book

files = {
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml': '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'content.opf': '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">rtl-probe</dc:identifier><dc:title>RTL probe</dc:title><dc:language>ar</dc:language><meta property="dcterms:modified">2026-11-05T00:00:00Z</meta></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/></manifest><spine page-progression-direction="rtl"><itemref idref="chapter"/></spine></package>',
    'nav.xhtml': '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol><li><a href="chapter.xhtml">البداية</a></li></ol></nav></body></html>',
    'chapter.xhtml': '<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" lang="ar" xml:lang="ar" dir="rtl"><head><title>البداية</title></head><body><h1>البداية</h1><p>مرحبا بالعالم <span dir="ltr" lang="en">English words</span> نهاية الفقرة.</p></body></html>',
}
with ZipFile('rtl-probe.epub', 'w') as archive:
    for name, content in files.items():
        archive.writestr(name, content)
subprocess.run(
    ['/sbin/entrypoint.sh', 'rtl-probe.epub', 'rtl-probe.kfx'],
    env=os.environ | {'KFX_BACKEND': 'kfxgen'},
    check=True,
)
book = YJ_Book(str(Path('rtl-probe.kfx').resolve()))
book.decode_book(pure=True)
document = next(fragment.value for fragment in book.fragments if str(fragment.ftype) == '$538')
if str(document['$192']) != '$375':
    raise AssertionError('Spine direction is not RTL')


def structs(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from structs(child)
    elif isinstance(value, (list, tuple)):
        for child in value:
            yield from structs(child)
    elif hasattr(value, 'value'):
        yield from structs(value.value)


values = [value for fragment in book.fragments for value in structs(fragment.value)]
if not any(value.get('$10') == 'ar' and str(value.get('$682')) == '$375' for value in values):
    raise AssertionError('Arabic RTL style missing')
if not any(value.get('$10') == 'en' and str(value.get('$682')) == '$376' for value in values):
    raise AssertionError('Inline English LTR style missing')
subprocess.run(['ebook-convert', 'rtl-probe.epub', 'rtl-probe.pdf', '--pdf-no-cover'], check=True)
subprocess.run(['/opt/calibre/bin/pdftotext', 'rtl-probe.pdf', 'rtl-probe.txt'], check=True)
text = Path('rtl-probe.txt').read_text()
if 'English' not in text or not re.search('[\u0600-\u06ff]', text):
    raise AssertionError('Arabic or English PDF text missing')
print('RTL KFX styles and Arabic PDF text passed')
