# Bilga purchase verifier

This is the server implementation for `CorePurchaseVerifier`. It is **not deployed**, and no Google credentials or production signing key are included. Local tests use generated keys, synthetic receipts and a fake Play API. A passing test suite is not a successful real purchase.

## Behavior

`POST /verify` accepts exactly the five fields the Flutter client sends: `packageName`, `productId`, `receipt`, `signature`, `installation`. Only `com.ilmmizan.bilga` / `bilga_lifetime_unlock` are accepted. The installation value is the app's random 128-bit trial identifier, not a hardware identifier.

The server verifies the original receipt's RSA signature using the Play Console public licensing key, checks its package/product/state, then queries Google Play with its purchase token. Purchased, unconsumed, single-quantity items are acknowledged if necessary and checked again before granting. Explicit Google cancellation produces a signed `revoked` response. Pending purchases, missing purchases, malformed responses, authentication failures, network errors and acknowledgment failures never produce a grant or revocation. The service never consumes, refunds or cancels purchases.

The response contains an exact UTF-8 JSON `payload` plus its Ed25519 `signature`. The payload binds version, package, product, installation, SHA-256 of the exact receipt, lifetime entitlement and status. The client pins the public key and verifies those fields. Its existing offline grant remains valid during outages. Importing the server modules neither starts a server nor loads credentials.

The SQLite ledger stores only a SHA-256 token digest, receipt digest, package, product, verification dates and last confirmed status. It does not store raw receipts, tokens, device identifiers, Google accounts or private Bilga content. Repeat verification and legitimate multi-device restores remain possible. A stolen genuine receipt can be replayed to request a new device-bound grant: an anonymous service cannot prove account ownership. The ledger and signed installation binding do not eliminate that limitation. There is no claim of tamper-proof client enforcement or immediate offline refund revocation.

## Test locally

From the repository root, using Python 3.11 or newer:

```sh
python3 -m venv /tmp/bilga-verifier-env
/tmp/bilga-verifier-env/bin/pip install -r backend/purchase_verifier/requirements.txt
/tmp/bilga-verifier-env/bin/python -m unittest discover -s backend/purchase_verifier/tests -v
```

No Play credentials, remote service or paid resource is needed for tests. The public fixture in `test/fixtures/purchase_verifier_grant.json` verifies Python-issued grants in Dart; it contains no private key.

## External setup before activation

1. Configure the lifetime non-consumable product in Play Console, authorize a dedicated service identity for the required purchase lookup/acknowledgment operations and enable the Android Publisher API. Supply server credentials through Application Default Credentials (prefer workload identity). Never put service-account JSON or the grant private key in Flutter defines, assets, logs or Git.
2. Put the Play Console RSA public licensing key in a server-readable file. Create a persistent private directory for the signing key and SQLite ledger, owned only by the service user (`umask 077`). Back it up securely. The keygen command below refuses to overwrite an existing file and prints only the public key. Do not run it on every restart or deploy.
3. Start the WSGI factory behind an HTTPS reverse proxy. Configure request/body and header limits, connection timeouts, rate limits and bounded worker concurrency there. Do not enable request-body or upstream token-URL logging; keep urllib3/Google transport debug logging disabled. Do not expose the WSGI HTTP port publicly. Use a persistent local SQLite volume; multiple machines need a shared transactional ledger implementation before scaling. Health only confirms the process is serving; it does not validate Play credentials.
4. Set the app's `BILGA_BILLING_VERIFY_URL` to the HTTPS `/verify` URL and `BILGA_BILLING_VERIFY_KEY` to the printed raw Ed25519 public key (base64). Retain the existing `BILGA_PLAY_LICENSE_KEY`. Public keys may be included in the app; private keys must remain on the server. Keep the same grant key: the current client pins one key and cached lifetime grants have no expiry. Key rotation requires an explicit client compatibility migration.
5. On an internal Play test track, test purchase, pending payment, repeated restore, acknowledgment, second-device restore, refund/revocation, network outage and offline restart with a genuine test account. Sideloaded Bilga Review cannot validate the production product. No Play publication or paid deployment is authorized by this implementation.

Example commands, after the operator supplies private paths and credentials:

```sh
python -m backend.purchase_verifier.keygen /private/bilga/signing.pem
export BILGA_SIGNING_KEY_FILE=/private/bilga/signing.pem
export BILGA_PLAY_LICENSE_KEY_FILE=/private/bilga/play-public-key.txt
export BILGA_LEDGER_FILE=/private/bilga/purchases.sqlite
# Supply ADC through the deployment's private identity configuration.
gunicorn 'backend.purchase_verifier.wsgi:create_app()' --bind 127.0.0.1:8080 --workers 2 --threads 1 --timeout 20 --access-logfile /dev/null
```

Requests are capped at 32 KiB, receipts at 16 KiB, Play responses at 32 KiB. Duplicate JSON keys and non-finite values are rejected. HTTPS redirects are not followed. HTTP errors expose fixed codes, never exception text or token-bearing URLs. TLS, traffic rate limiting and operational monitoring are deployment responsibilities, not completed acceptance checks.

## Primary references

- [Google Play verification and fraud guidance](https://developer.android.com/google/play/billing/security)
- [Purchase lookup](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get), [purchase states](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products), [acknowledgment](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/acknowledge)
- [Application Default Credentials](https://google-auth.readthedocs.io/en/latest/reference/google.auth.html), [AuthorizedSession timeouts](https://google-auth.readthedocs.io/en/latest/reference/google.auth.transport.requests.html)
