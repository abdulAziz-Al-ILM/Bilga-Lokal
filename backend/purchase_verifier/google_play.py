"""Fixed-host Google Play adapter. No purchase URLs or credentials are logged."""
from urllib.parse import quote

from .core import PACKAGE, PRODUCT, PlayUnavailable, strict_json, VerificationError


class GooglePublisher:
    def __init__(self, session):
        self.session = session

    @classmethod
    def from_adc(cls):
        import google.auth
        from google.auth.transport.requests import AuthorizedSession
        credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/androidpublisher"])
        return cls(AuthorizedSession(credentials, max_refresh_attempts=1, refresh_timeout=3))

    @staticmethod
    def url(token):
        return ("https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                f"{PACKAGE}/purchases/products/{PRODUCT}/tokens/{quote(token, safe='')}")

    def request(self, method, url):
        response = None
        try:
            response = self.session.request(method, url, timeout=(2, 3), max_allowed_time=4,
                allow_redirects=False, stream=True,
                **({"json": {}} if method == "POST" else {}))
            if response.status_code not in (200, 204):
                raise PlayUnavailable()
            if method == "POST":
                return None
            body = bytearray()
            for chunk in response.iter_content(chunk_size=4096):
                if len(body) + len(chunk) > 32768:
                    raise PlayUnavailable()
                body.extend(chunk)
            return strict_json(bytes(body))
        except VerificationError:
            raise PlayUnavailable() from None
        except Exception:
            # Never propagate requests exceptions: their message contains the
            # token-bearing URL. Logs and HTTP responses expose only this code.
            raise PlayUnavailable() from None
        finally:
            if response is not None:
                response.close()

    def get(self, token):
        return self.request("GET", self.url(token))

    def acknowledge(self, token):
        self.request("POST", self.url(token) + ":acknowledge")
