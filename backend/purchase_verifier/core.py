"""Verify receipts before querying Play; sign the exact client protocol bytes."""
from __future__ import annotations

import base64
import hashlib
import json
import re
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Protocol

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, padding, rsa

PACKAGE = "com.ilmmizan.bilga"
PRODUCT = "bilga_lifetime_unlock"
MAX_BODY = 32768


class VerificationError(Exception):
    def __init__(self, code: str, status: int = 400):
        self.code, self.status = code, status
        super().__init__(code)


class PlayUnavailable(VerificationError):
    def __init__(self):
        super().__init__("play_unavailable", 503)


def strict_json(raw: str | bytes) -> dict:
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate key")
            result[key] = value
        return result

    try:
        result = json.loads(raw, object_pairs_hook=pairs,
                            parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
        if not isinstance(result, dict):
            raise ValueError()
        return result
    except (ValueError, TypeError, RecursionError, UnicodeError):
        raise VerificationError("invalid_request") from None


def load_license_key(raw: bytes) -> rsa.RSAPublicKey:
    try:
        if raw.startswith(b"-----BEGIN"):
            key = serialization.load_pem_public_key(raw)
        else:
            key = serialization.load_der_public_key(base64.b64decode(raw.strip(), validate=True))
        if not isinstance(key, rsa.RSAPublicKey) or key.key_size < 2048:
            raise ValueError()
        return key
    except (ValueError, TypeError):
        raise ValueError("Expected the Play Console RSA public licensing key") from None


class Publisher(Protocol):
    def get(self, token: str) -> dict: ...
    def acknowledge(self, token: str) -> None: ...


@dataclass(frozen=True)
class Receipt:
    raw: str
    token: str
    installation: str

    @property
    def digest(self):
        return hashlib.sha256(self.raw.encode("utf-8")).hexdigest()

    @property
    def token_digest(self):
        return hashlib.sha256(self.token.encode("utf-8")).hexdigest()


def verify_request(body: bytes, key: rsa.RSAPublicKey) -> Receipt:
    if len(body) > MAX_BODY:
        raise VerificationError("request_too_large", 413)
    request = strict_json(body)
    if set(request) != {"packageName", "productId", "installation", "receipt", "signature"}:
        raise VerificationError("invalid_request")
    if request["packageName"] != PACKAGE or request["productId"] != PRODUCT:
        raise VerificationError("invalid_product")
    installation, raw, signature = (request[k] for k in ("installation", "receipt", "signature"))
    if not isinstance(installation, str) or not re.fullmatch(r"[0-9a-f]{32}", installation):
        raise VerificationError("invalid_request")
    if not isinstance(raw, str) or not 1 <= len(raw) <= 16384:
        raise VerificationError("invalid_receipt")
    if not isinstance(signature, str) or len(signature) > 1024:
        raise VerificationError("invalid_receipt")
    try:
        # Google Play's signed originalJson uses SHA1withRSA (same as Android).
        key.verify(base64.b64decode(signature, validate=True), raw.encode("utf-8"),
                   padding.PKCS1v15(), hashes.SHA1())
    except (InvalidSignature, ValueError, TypeError, UnicodeError):
        raise VerificationError("invalid_receipt") from None
    receipt = strict_json(raw)
    if (receipt.get("packageName") != PACKAGE or receipt.get("productId") != PRODUCT
            or type(receipt.get("purchaseState")) is not int or receipt["purchaseState"] != 0):
        raise VerificationError("invalid_receipt")
    token = receipt.get("purchaseToken", receipt.get("token"))
    if (not isinstance(token, str) or not 1 <= len(token) <= 4096
            or any(ord(c) < 33 or ord(c) > 126 for c in token)):
        raise VerificationError("invalid_receipt")
    if "token" in receipt and receipt["token"] != token:
        raise VerificationError("invalid_receipt")
    return Receipt(raw, token, installation)


def play_state(data: dict, token: str) -> str:
    if not isinstance(data, dict):
        raise PlayUnavailable()
    if (("productId" in data and data["productId"] != PRODUCT)
            or ("purchaseToken" in data and data["purchaseToken"] != token)):
        raise PlayUnavailable()
    state = data.get("purchaseState")
    if type(state) is not int or state not in (0, 1, 2):
        raise PlayUnavailable()
    if state == 1:
        return "revoked"
    if state == 2:
        raise VerificationError("purchase_pending", 409)
    if (type(data.get("consumptionState")) is not int or data["consumptionState"] != 0
            or type(data.get("quantity", 1)) is not int or data.get("quantity", 1) != 1
            or type(data.get("acknowledgementState")) is not int
            or data["acknowledgementState"] not in (0, 1)):
        raise PlayUnavailable()
    return "purchased"


class TokenLedger:
    """Hashed token metadata only. A token is never consumed or device-locked.

    This supports legitimate multi-device restores without a Bilga account.
    It does not authenticate ownership of a copied genuine receipt.
    """
    def __init__(self, path: str):
        self.path = path
        with self.connect() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS purchases (
                token_sha256 TEXT PRIMARY KEY, package_name TEXT NOT NULL,
                product_id TEXT NOT NULL, receipt_sha256 TEXT NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('purchased', 'revoked')),
                first_verified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_verified TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)""")

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=5)
        try:
            db.execute("PRAGMA synchronous=FULL")
            db.execute("PRAGMA secure_delete=ON")
            with db:
                yield db
        finally:
            db.close()

    def record(self, receipt: Receipt, status: str):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            old = db.execute("SELECT package_name, product_id FROM purchases WHERE token_sha256=?",
                             (receipt.token_digest,)).fetchone()
            if old is not None and old != (PACKAGE, PRODUCT):
                raise VerificationError("invalid_receipt")
            db.execute("""INSERT INTO purchases(token_sha256, package_name, product_id,
                receipt_sha256, status) VALUES(?, ?, ?, ?, ?)
                ON CONFLICT(token_sha256) DO UPDATE SET receipt_sha256=excluded.receipt_sha256,
                status=excluded.status, last_verified=CURRENT_TIMESTAMP""",
                (receipt.token_digest, PACKAGE, PRODUCT, receipt.digest, status))


class Verifier:
    def __init__(self, license_key: rsa.RSAPublicKey, signer: ed25519.Ed25519PrivateKey,
                 publisher: Publisher, ledger: TokenLedger):
        self.license_key, self.signer = license_key, signer
        self.publisher, self.ledger = publisher, ledger

    def verify(self, body: bytes) -> dict:
        receipt = verify_request(body, self.license_key)
        data = self.publisher.get(receipt.token)
        status = play_state(data, receipt.token)
        if status == "purchased" and data["acknowledgementState"] == 0:
            try:
                self.publisher.acknowledge(receipt.token)
            except PlayUnavailable:
                # Another restore may have acknowledged concurrently. Only an
                # authoritative reread can turn that failure into success.
                data = self.publisher.get(receipt.token)
                status = play_state(data, receipt.token)
                if status == "purchased" and data["acknowledgementState"] != 1:
                    raise PlayUnavailable() from None
            else:
                # Re-read after acknowledgement to catch a cancellation race.
                data = self.publisher.get(receipt.token)
                status = play_state(data, receipt.token)
                if status == "purchased" and data["acknowledgementState"] != 1:
                    raise PlayUnavailable()
        try:
            self.ledger.record(receipt, status)
        except sqlite3.Error:
            raise VerificationError("storage_unavailable", 503) from None
        payload = json.dumps({
            "version": 1, "packageName": PACKAGE, "productId": PRODUCT,
            "installation": receipt.installation, "receiptSha256": receipt.digest,
            "entitlement": "lifetime", "status": status,
        }, ensure_ascii=False, separators=(",", ":"))
        return {"payload": payload, "signature": base64.b64encode(
            self.signer.sign(payload.encode("utf-8"))).decode("ascii")}
