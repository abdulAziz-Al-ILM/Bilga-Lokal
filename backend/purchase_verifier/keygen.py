"""Explicit operator command: create a NEW key, refusing to overwrite any file."""
import base64
import os
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python -m backend.purchase_verifier.keygen /private/path/signing.pem")
    key = Ed25519PrivateKey.generate()
    fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as target:
        target.write(key.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        target.flush()
        os.fsync(target.fileno())
    print(base64.b64encode(key.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode("ascii"))


if __name__ == "__main__":
    main()
