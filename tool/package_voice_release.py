#!/usr/bin/env python3
"""Build a deterministic data-only archive from an exact, hash-verified allowlist."""
import argparse
import json
from pathlib import Path
import zipfile

from prepare_uzbek_voice import verified, digest


def package(payload_path, assets, archive):
    payload = json.loads(payload_path.read_text())
    models = payload['models']
    if len(models) != 1:
        raise ValueError('This packager expects exactly one reviewed model')
    entries = models[0]['files']
    names = set()
    for entry in entries:
        path = Path(entry['path'])
        asset = entry['asset']
        if (path.is_absolute() or '..' in path.parts or '\\' in str(path)
                or path.as_posix() in names or Path(asset).name != asset
                or not verified(assets / asset, entry)):
            raise ValueError('Unsafe path or pinned file mismatch')
        names.add(path.as_posix())
    # Exact files only. No recursive directory copy, private checkout or keys.
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for entry in sorted(entries, key=lambda f: f['path']):
            info = zipfile.ZipInfo(entry['path'], date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            with (assets / entry['asset']).open('rb') as src, output.open(info, 'w') as dst:
                while block := src.read(1024 * 1024):
                    dst.write(block)
    with zipfile.ZipFile(archive) as output:
        if output.testzip() is not None:
            raise ValueError('Archive CRC failed')
    # Signed by the same catalog, even though the app consumes flat files.
    payload['artifacts'] = [{'asset': archive.name, 'bytes': archive.stat().st_size,
                             'sha256': digest(archive), 'format': 'zip',
                             'model': models[0]['id']}]
    payload_path.write_text(json.dumps(payload, indent=2) + '\n')
    print(f'{archive.name}: {archive.stat().st_size} bytes, SHA-256 {digest(archive)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('payload', type=Path)
    parser.add_argument('assets', type=Path)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    package(args.payload, args.assets, args.archive)
