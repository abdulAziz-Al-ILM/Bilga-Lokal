#!/usr/bin/env python3
"""Maintainer-only acquisition; never signs, publishes or consumes user data.

Pins the original publisher's commit, sizes and SHA-256 before creating a draft.
Output is deliberately unreviewed on Android and cannot pass the release signer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verified(path, entry):
    return (path.is_file() and path.stat().st_size == entry['bytes']
            and digest(path) == entry['sha256'])


def acquire(url, target, entry):
    if verified(target, entry):
        return
    part = target.with_name(target.name + '.part')
    offset = part.stat().st_size if part.exists() else 0
    if offset >= entry['bytes']:
        if verified(part, entry):
            part.replace(target)
            return
        part.unlink()
        offset = 0
    request = urllib.request.Request(url, headers={'Range': f'bytes={offset}-'} if offset else {})
    with urllib.request.urlopen(request, timeout=60) as response:
        if not response.url.startswith('https://'):
            raise ValueError('Non-HTTPS redirect')
        if response.status == 206:
            match = re.fullmatch(r'bytes (\d+)-(\d+)/(\d+)', response.headers.get('Content-Range', ''))
            if not match or int(match[1]) != offset or int(match[3]) != entry['bytes']:
                raise ValueError('Invalid resume response')
        elif response.status == 200:
            offset = 0
        else:
            raise ValueError(f'Unexpected HTTP status {response.status}')
        with part.open('ab' if offset else 'wb') as stream:
            while block := response.read(1024 * 1024):
                offset += len(block)
                if offset > entry['bytes']:
                    raise ValueError('Oversized upstream file')
                stream.write(block)
                print(f'{target.name}: {offset}/{entry["bytes"]}', flush=True)
    if not verified(part, entry):
        part.unlink(missing_ok=True)
        raise ValueError(f'Upstream SHA-256/size rejected: {target.name}')
    part.replace(target)


def prepare(output, revision, expires):
    here = Path(__file__).resolve().parent
    lock = json.loads((here / 'voice_models/uzbek_stt.lock.json').read_text())
    assets = output / 'assets'
    assets.mkdir(parents=True, exist_ok=True)
    files = []
    for entry in lock['files']:
        url = f'https://huggingface.co/{lock["repository"]}/resolve/{lock["commit"]}/{entry["upstream"]}'
        acquire(url, assets / entry['asset'], entry)
        files.append({k: entry[k] for k in ('path', 'asset', 'bytes', 'sha256')})
    notices = {
        'LICENSE.txt': (here / 'voice_models/APACHE-2.0.txt').read_bytes(),
        'NOTICE.txt': (f'Vosk Uzbek Speech Recognition Model 0.60\n'
                       f'Publisher: Alpha Cephei Inc.\n'
                       f'https://huggingface.co/{lock["repository"]}/tree/{lock["commit"]}\n'
                       'Upstream declares Apache-2.0; original model card is UPSTREAM.md.\n'
                       'ONNX/token files are unmodified. Packaged for Bilga.\n').encode(),
    }
    for name, data in notices.items():
        asset = 'vosk-uz-060-' + name
        (assets / asset).write_bytes(data)
        files.append({'path': name, 'asset': asset, 'bytes': len(data),
                      'sha256': hashlib.sha256(data).hexdigest()})
    model = {
        'id': lock['id'], 'version': lock['version'], 'kind': 'stt', 'engine': 'streaming_transducer',
        'languages': ['uz'], 'license': lock['license'],
        'licenseUrl': f'https://huggingface.co/{lock["repository"]}/blob/{lock["commit"]}/README.md',
        'licenseReviewed': True, 'androidReviewed': False,
        'androidMinSdk': 31, 'androidAbis': ['arm64-v8a'],
        'files': files,
        'config': {'encoder': 'encoder.onnx', 'decoder': 'decoder.onnx',
                   'joiner': 'joiner.onnx', 'tokens': 'tokens.txt'},
    }
    payload = {'schema': 1, 'revision': revision, 'expires': expires, 'models': [model]}
    (output / 'catalog.draft.json').write_text(json.dumps(payload, indent=2) + '\n')
    print('Verified assets and catalog.draft.json prepared. Android review, external signing and publishing still required.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--revision', type=int, default=1)
    parser.add_argument('--expires', required=True, help='UTC ISO8601 expiry, e.g. 2027-01-01T00:00:00Z')
    args = parser.parse_args()
    prepare(args.output, args.revision, args.expires)
