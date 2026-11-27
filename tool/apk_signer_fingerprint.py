#!/usr/bin/env python3
"""Extract SHA-256 certificate fingerprints from APK v2/v3 signing metadata.

This does not verify signatures. Use apksigner verify before installation.
It never reads device databases or private signing keys.
"""
import hashlib
import mmap
import struct
import sys


def length_prefixed(data, offset=0):
    if offset + 4 > len(data):
        raise ValueError('Truncated APK signing metadata')
    size = struct.unpack_from('<I', data, offset)[0]
    end = offset + 4 + size
    if end > len(data):
        raise ValueError('Invalid APK signing metadata length')
    return data[offset + 4:end], end


def fingerprints(path):
    with open(path, 'rb') as file, mmap.mmap(file.fileno(), 0, access=mmap.ACCESS_READ) as apk:
        end = apk.rfind(b'PK\x05\x06', max(0, len(apk) - 65557))
        if end < 0:
            raise ValueError('ZIP end directory missing')
        directory = struct.unpack_from('<I', apk, end + 16)[0]
        if directory < 24 or apk[directory - 16:directory] != b'APK Sig Block 42':
            raise ValueError('APK v2/v3 signing block missing')
        size = struct.unpack_from('<Q', apk, directory - 24)[0]
        start = directory - size - 8
        if start < 0 or struct.unpack_from('<Q', apk, start)[0] != size:
            raise ValueError('Invalid APK signing block')
        offset, found = start + 8, set()
        while offset < directory - 24:
            length = struct.unpack_from('<Q', apk, offset)[0]
            offset += 8
            if length < 4 or offset + length > directory - 24:
                raise ValueError('Invalid APK signing entry')
            kind = struct.unpack_from('<I', apk, offset)[0]
            value = apk[offset + 4:offset + length]
            offset += length
            if kind not in {0x7109871A, 0xF05368C0}:
                continue
            signers, _ = length_prefixed(value)
            cursor = 0
            while cursor < len(signers):
                signer, cursor = length_prefixed(signers, cursor)
                signed, _ = length_prefixed(signer)
                _, digest_end = length_prefixed(signed)
                certificates, _ = length_prefixed(signed, digest_end)
                certificate, _ = length_prefixed(certificates)
                found.add(hashlib.sha256(certificate).hexdigest())
        if not found:
            raise ValueError('No supported signing certificates')
        return sorted(found)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: apk_signer_fingerprint.py <apk>')
    for fingerprint in fingerprints(sys.argv[1]):
        print(fingerprint)
