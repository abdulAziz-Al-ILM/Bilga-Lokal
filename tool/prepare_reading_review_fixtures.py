#!/usr/bin/env python3
"""Generate original legal SAF acceptance documents; no owner files are read."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED


def pdf(pages=5):
    objects = [b'<< /Type /Catalog /Pages 2 0 R >>', b'', b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
    kids = []
    for page in range(1, pages + 1):
        i = len(objects) + 1
        kids.append(f'{i} 0 R')
        objects.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] /Resources << /Font << /F1 3 0 R >> >> /Contents {i+1} 0 R >>'.encode())
        content = f'BT /F1 18 Tf 40 530 Td (Bilga original page {page}) Tj 0 -35 Td (Remember this synthetic passage.) Tj ET'.encode()
        objects.append(f'<< /Length {len(content)} >>\nstream\n'.encode() + content + b'\nendstream')
    objects[1] = f'<< /Type /Pages /Kids [{" ".join(kids)}] /Count {pages} >>'.encode()
    output = bytearray(b'%PDF-1.4\n')
    offsets = [0]
    for i, value in enumerate(objects, 1):
        offsets.append(len(output))
        output.extend(f'{i} 0 obj\n'.encode() + value + b'\nendobj\n')
    xref = len(output)
    output.extend(f'xref\n0 {len(objects)+1}\n0000000000 65535 f \n'.encode())
    for offset in offsets[1:]:
        output.extend(f'{offset:010} 00000 n \n'.encode())
    output.extend(f'trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    args.directory.mkdir(parents=True, exist_ok=False)
    (args.directory / 'BilgaReaderFixture-PDF.pdf').write_bytes(pdf())
    (args.directory / 'BilgaReaderFixture-TXT.txt').write_text('Original Bilga SAF text.\n\nA legal demonstration for offline reading.\n\nRemember this idea.\n', encoding='utf8')
    (args.directory / 'BilgaReaderFixture-Invalid.epub').write_bytes(b'PK\x03\x04invalid original fixture')
    with ZipFile(args.directory / 'BilgaReaderFixture-EPUB.epub', 'w', ZIP_DEFLATED) as z:
        z.writestr('mimetype', 'application/epub+zip')
        z.writestr('META-INF/container.xml', '<container><rootfiles><rootfile full-path="book.opf"/></rootfiles></container>')
        z.writestr('book.opf', '<package xmlns:dc="http://purl.org/dc/elements/1.1/"><metadata><dc:title>Original SAF EPUB</dc:title></metadata><manifest><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>')
        z.writestr('one.xhtml', '<html><body><h1>Original first chapter</h1><p>Remember this original legal passage.</p></body></html>')
        z.writestr('two.xhtml', '<html><body><h1>Original second chapter</h1><p>Apply the idea in your own words.</p></body></html>')
    print(f'Generated four original fixtures in {args.directory}')


if __name__ == '__main__':
    main()
