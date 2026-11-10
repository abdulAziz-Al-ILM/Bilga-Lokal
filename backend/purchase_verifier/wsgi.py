"""WSGI factory; importing this module does not load credentials or start a server."""
import json
import os
from http import HTTPStatus
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from .core import MAX_BODY, TokenLedger, VerificationError, Verifier, load_license_key
from .google_play import GooglePublisher


class Application:
    def __init__(self, verifier):
        self.verifier = verifier

    def __call__(self, environ, start_response):
        try:
            path, method = environ.get("PATH_INFO"), environ.get("REQUEST_METHOD")
            if path == "/healthz" and method == "GET":
                status, result = 200, {"status": "ok"}
            elif path != "/verify":
                raise VerificationError("not_found", 404)
            elif method != "POST":
                raise VerificationError("method_not_allowed", 405)
            else:
                if (environ.get("CONTENT_TYPE", "").split(";", 1)[0].strip().lower()
                        != "application/json"):
                    raise VerificationError("unsupported_media_type", 415)
                if environ.get("HTTP_TRANSFER_ENCODING") or environ.get("HTTP_CONTENT_ENCODING"):
                    raise VerificationError("invalid_request")
                length = environ.get("CONTENT_LENGTH", "")
                if not length:
                    raise VerificationError("length_required", 411)
                if not length.isascii() or not length.isdigit() or len(length) > 8:
                    raise VerificationError("invalid_request")
                length = int(length)
                if length > MAX_BODY:
                    raise VerificationError("request_too_large", 413)
                body = environ["wsgi.input"].read(length)
                if len(body) != length:
                    raise VerificationError("invalid_request")
                result = self.verifier.verify(body)
                status = 200
        except VerificationError as error:
            status, result = error.status, {"error": error.code}
        except Exception:
            # No exception strings, request bodies, identifiers or stack traces.
            status, result = 503, {"error": "verification_unavailable"}
        body = json.dumps(result, separators=(",", ":")).encode("utf-8")
        start_response(f"{status} {HTTPStatus(status).phrase}", [
            ("Content-Type", "application/json; charset=utf-8"),
            ("Content-Length", str(len(body))), ("Cache-Control", "no-store"),
            ("X-Content-Type-Options", "nosniff"),
        ])
        return [body]


def create_app():
    # These are server-only file PATHS; never Flutter defines or APK assets.
    signer = serialization.load_pem_private_key(
        Path(os.environ["BILGA_SIGNING_KEY_FILE"]).read_bytes(), password=None)
    if not isinstance(signer, Ed25519PrivateKey):
        raise ValueError("BILGA_SIGNING_KEY_FILE must be an Ed25519 private key")
    license_key = load_license_key(Path(os.environ["BILGA_PLAY_LICENSE_KEY_FILE"]).read_bytes())
    ledger = TokenLedger(os.environ["BILGA_LEDGER_FILE"])
    return Application(Verifier(license_key, signer, GooglePublisher.from_adc(), ledger))
