import base64
import copy
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, padding, rsa

from backend.purchase_verifier.core import (
    PACKAGE, PRODUCT, MAX_BODY, PlayUnavailable, TokenLedger,
    VerificationError, Verifier, load_license_key,
)
from backend.purchase_verifier.google_play import GooglePublisher
from backend.purchase_verifier.wsgi import Application
from backend.purchase_verifier import keygen


class FakePublisher:
    def __init__(self):
        self.data = {"purchaseState": 0, "consumptionState": 0, "acknowledgementState": 0}
        self.get_calls, self.ack_calls = 0, 0
        self.offline = self.ack_fails = self.concurrent_ack = self.cancel_on_ack = False

    def get(self, token):
        self.get_calls += 1
        if self.offline:
            raise PlayUnavailable()
        return copy.deepcopy(self.data)

    def acknowledge(self, token):
        self.ack_calls += 1
        if self.cancel_on_ack:
            self.data["purchaseState"] = 1
        if not self.ack_fails or self.concurrent_ack:
            self.data["acknowledgementState"] = 1
        if self.ack_fails:
            raise PlayUnavailable()


class VerifierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.google_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = str(Path(self.temp.name) / "ledger.sqlite")
        self.signer = ed25519.Ed25519PrivateKey.generate()
        self.play = FakePublisher()
        self.verifier = Verifier(self.google_key.public_key(), self.signer, self.play, TokenLedger(self.path))
        self.receipt = {"packageName": PACKAGE, "productId": PRODUCT,
                        "purchaseState": 0, "purchaseToken": "synthetic-token"}

    def body(self, receipt=None, **change):
        raw = json.dumps(self.receipt if receipt is None else receipt, ensure_ascii=False)
        return self.body_raw(raw, **change)

    def body_raw(self, raw, **change):
        signature = self.google_key.sign(raw.encode(), padding.PKCS1v15(), hashes.SHA1())
        return json.dumps({"packageName": PACKAGE, "productId": PRODUCT,
            "installation": "a" * 32, "receipt": raw,
            "signature": base64.b64encode(signature).decode(), **change}).encode()

    def grant(self, body=None):
        result = self.verifier.verify(body or self.body())
        self.signer.public_key().verify(base64.b64decode(result["signature"]), result["payload"].encode())
        return json.loads(result["payload"])

    def rows(self):
        db = sqlite3.connect(self.path)
        try:
            return db.execute("SELECT * FROM purchases").fetchall()
        finally:
            db.close()

    def test_purchase_acknowledged_before_signed_grant_and_hashed_ledger(self):
        self.assertEqual(self.grant()["status"], "purchased")
        self.assertEqual((self.play.get_calls, self.play.ack_calls), (2, 1))
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertNotIn("synthetic-token", str(rows))
        self.assertNotIn("a" * 32, str(rows))

    def test_repeat_and_other_device_restore_does_not_consume_or_device_lock(self):
        first = self.grant()
        second = self.grant(self.body(installation="b" * 32))
        self.assertEqual(second["status"], "purchased")
        self.assertNotEqual(first["installation"], second["installation"])
        self.assertEqual(self.play.ack_calls, 1)
        self.assertEqual(len(self.rows()), 1)

    def test_forged_signature_rejected_before_any_play_request(self):
        with self.assertRaises(VerificationError):
            self.verifier.verify(self.body(signature="AAAA"))
        self.assertEqual(self.play.get_calls, 0)

    def test_changed_exact_receipt_bytes_reject(self):
        request = json.loads(self.body())
        request["receipt"] += " "
        with self.assertRaises(VerificationError):
            self.verifier.verify(json.dumps(request).encode())

    def test_wrong_product_package_installation_and_unexpected_content_reject(self):
        for change in ({"productId": "bilga_agent_start"}, {"packageName": "other.app"},
                       {"installation": "hardware-id"}, {"notes": ["private"]}):
            with self.subTest(change=change), self.assertRaises(VerificationError):
                self.verifier.verify(self.body(**change))
        for change in ({"productId": "other"}, {"packageName": "other"},
                       {"purchaseState": True}, {"purchaseState": 2},
                       {"purchaseToken": ""}, {"token": "mismatched"}):
            with self.subTest(change=change), self.assertRaises(VerificationError):
                self.verifier.verify(self.body(receipt={**self.receipt, **change}))
        self.assertEqual(self.play.get_calls, 0)

    def test_ambiguous_json_and_oversized_requests_reject(self):
        for raw in ('{"x":1,"x":2}', '{"x":NaN}', '[]'):
            with self.subTest(raw=raw), self.assertRaises(VerificationError):
                self.verifier.verify(self.body_raw(raw))
        with self.assertRaises(VerificationError) as caught:
            self.verifier.verify(b"x" * (MAX_BODY + 1))
        self.assertEqual(caught.exception.status, 413)

    def test_pending_never_acknowledged_or_granted(self):
        self.play.data["purchaseState"] = 2
        with self.assertRaises(VerificationError) as caught:
            self.grant()
        self.assertEqual(caught.exception.status, 409)
        self.assertEqual(self.play.ack_calls, 0)
        self.assertFalse(self.rows())

    def test_explicit_google_cancellation_only_signs_revoked(self):
        self.play.data["purchaseState"] = 1
        self.assertEqual(self.grant()["status"], "revoked")
        self.assertEqual(self.play.ack_calls, 0)

    def test_outage_does_not_grant_revoke_or_overwrite_last_ledger_state(self):
        self.grant()
        before = self.rows()
        self.play.offline = True
        with self.assertRaises(PlayUnavailable):
            self.grant()
        self.assertEqual(self.rows(), before)

    def test_ack_failure_never_grants_without_authoritative_ack(self):
        self.play.ack_fails = True
        with self.assertRaises(PlayUnavailable):
            self.grant()
        self.assertFalse(self.rows())
        self.play.concurrent_ack = True
        self.assertEqual(self.grant()["status"], "purchased")

    def test_cancellation_during_ack_does_not_grant(self):
        self.play.cancel_on_ack = True
        self.assertEqual(self.grant()["status"], "revoked")

    def test_malformed_or_mismatched_google_data_cannot_grant_or_revoke(self):
        for change in ({"purchaseState": True}, {"purchaseState": 7},
                       {"consumptionState": 1}, {"acknowledgementState": True},
                       {"productId": "other"}, {"purchaseToken": "different"},
                       {"quantity": 2}, {"quantity": True}):
            old = self.play.data.copy()
            self.play.data.update(change)
            with self.subTest(change=change), self.assertRaises(PlayUnavailable):
                self.grant()
            self.play.data = old

    def test_license_key_import_accepts_console_der_and_pem(self):
        public = self.google_key.public_key()
        for raw in (public.public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo),
                    base64.b64encode(public.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo))):
            self.assertEqual(load_license_key(raw).public_numbers(), public.public_numbers())
        with self.assertRaises(ValueError):
            load_license_key(b"wrong")

    def test_missing_ledger_cannot_emit_an_unrecorded_grant(self):
        Path(self.path).unlink()
        Path(self.path).mkdir()
        with self.assertRaises(VerificationError) as caught:
            self.grant()
        self.assertEqual(caught.exception.code, "storage_unavailable")

    def test_key_generation_is_private_and_never_replaces_an_existing_key(self):
        path = Path(self.temp.name) / "signing.pem"
        output = io.StringIO()
        with patch("sys.argv", ["keygen", str(path)]), redirect_stdout(output):
            keygen.main()
        original = path.read_bytes()
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        key = serialization.load_pem_private_key(original, password=None)
        self.assertEqual(base64.b64decode(output.getvalue().strip()), key.public_key().public_bytes(
            serialization.Encoding.Raw, serialization.PublicFormat.Raw))
        with patch("sys.argv", ["keygen", str(path)]), self.assertRaises(FileExistsError):
            keygen.main()
        self.assertEqual(path.read_bytes(), original)

    def test_http_limits_method_health_and_no_sensitive_errors(self):
        app = Application(self.verifier)

        def call(path="/verify", method="POST", body=None, **change):
            body = self.body() if body is None else body
            environ = {"PATH_INFO": path, "REQUEST_METHOD": method,
                "CONTENT_TYPE": "application/json", "CONTENT_LENGTH": str(len(body)),
                "wsgi.input": io.BytesIO(body), **change}
            response = []
            result = b"".join(app(environ, lambda status, headers: response.append((status, dict(headers)))))
            self.assertEqual(response[0][1]["Cache-Control"], "no-store")
            self.assertNotIn(b"synthetic-token", result)
            return int(response[0][0][:3]), json.loads(result)

        self.assertEqual(call("/healthz", "GET")[0], 200)
        self.assertEqual(call(method="GET")[0], 405)
        self.assertEqual(call("/other")[0], 404)
        self.assertEqual(call(CONTENT_TYPE="text/plain")[0], 415)
        self.assertEqual(call(CONTENT_LENGTH="")[0], 411)
        self.assertEqual(call(CONTENT_LENGTH=str(MAX_BODY + 1))[0], 413)
        self.assertEqual(call(CONTENT_LENGTH="10", body=b"{}")[0], 400)
        self.assertEqual(call(HTTP_TRANSFER_ENCODING="chunked")[0], 400)
        self.assertEqual(call()[0], 200)
        self.play.offline = True
        self.assertEqual(call(), (503, {"error": "play_unavailable"}))


class AdapterTests(unittest.TestCase):
    def test_fixed_host_escaped_token_bounded_response_and_no_redirects(self):
        class Response:
            status_code = 200
            closed = False
            body = b'{"purchaseState":0}'
            def iter_content(self, chunk_size):
                yield self.body
            def close(self):
                self.closed = True
        class Session:
            response = Response()
            def request(self, method, url, **kwargs):
                self.args = method, url, kwargs
                return self.response
        session = Session()
        publisher = GooglePublisher(session)
        self.assertEqual(publisher.get("token/with?query"), {"purchaseState": 0})
        self.assertTrue(session.args[1].endswith("token%2Fwith%3Fquery"))
        self.assertFalse(session.args[2]["allow_redirects"])
        self.assertTrue(session.response.closed)
        session.response.status_code = 302
        with self.assertRaises(PlayUnavailable):
            publisher.get("token")
        session.response.status_code = 200
        session.response.body = b"x" * 32769
        with self.assertRaises(PlayUnavailable):
            publisher.get("token")


if __name__ == "__main__":
    unittest.main()
