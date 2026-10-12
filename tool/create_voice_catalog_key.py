#!/usr/bin/env python3
"""Create a new model-catalog seed outside the checkout; never print its bytes."""
import argparse
import base64
import os
from pathlib import Path
import secrets
import stat


def create_key(path, checkout):
    path, checkout = Path(path).absolute(), Path(checkout).resolve()
    if path.resolve().is_relative_to(checkout):
        raise ValueError('Private key must be outside the project')
    if path.parent.is_symlink():
        raise ValueError('Key directory must not be a symlink')
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    parent = path.parent.stat()
    if parent.st_uid != os.getuid() or stat.S_IMODE(parent.st_mode) != 0o700:
        raise ValueError('Key directory must be owned by this user with mode 0700')
    # Never overwrite a key or follow a pre-existing symlink.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as output:
        output.write(base64.b64encode(secrets.token_bytes(32)) + b'\n')
        output.flush()
        os.fsync(output.fileno())
    print(f'Created private seed: {path} (0600; directory 0700). Back it up securely offline.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    create_key(args.path, Path(__file__).resolve().parents[1])
