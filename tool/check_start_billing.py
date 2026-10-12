"""Fail before a paid release when the public Google Play licensing key is absent."""
import base64
import json
import pathlib
import sys
import re
from urllib.parse import urlparse

root = pathlib.Path(__file__).resolve().parents[1]
try:
    config = json.loads((root / 'billing_config.json').read_text())
    key = config['BILGA_PLAY_LICENSE_KEY']
    raw = base64.b64decode(key, validate=True)
    if len(raw) < 200 or raw[0] != 0x30:
        raise ValueError('invalid public key')
    if config.get('BILGA_TURBO_INCLUDED') in (True, 'true') and 'package:llama_flutter_android' not in (root / 'lib/features/agent/turbo_engine.dart').read_text():
        raise ValueError('Turbo cannot be sold without native module')
    if config.get('BILGA_AGENT_PREVIEW'):
        raise ValueError('preview must not be in billing config')
    if config.get('BILGA_TRIAL_TEST'):
        raise ValueError('trial test mode must not be in release config')
    verifier = urlparse(config['BILGA_BILLING_VERIFY_URL'])
    if verifier.scheme != 'https' or not verifier.hostname or verifier.username or verifier.fragment or 'YOUR_' in verifier.netloc:
        raise ValueError('trusted HTTPS verification server required')
    if len(base64.b64decode(config['BILGA_BILLING_VERIFY_KEY'], validate=True)) != 32:
        raise ValueError('Ed25519 verifier public key required')
    if not re.fullmatch(r'[a-z0-9][a-z0-9_.]*', config['BILGA_CORE_PRODUCT_ID']):
        raise ValueError('Core non-consumable product ID required')
    if config['BILGA_CORE_PRODUCT_ID'] in {'bilga_agent_start', 'bilga_agent_turbo', 'bilga_agent_turbo_upgrade', 'bilga_finance'}:
        raise ValueError('Core product ID must not replace legacy receipt IDs')
except (OSError, ValueError, KeyError, TypeError):
    sys.exit('STOP: billing_config.json da Play public key, Core product ID va HTTPS verifier URL/Ed25519 public key kerak. BILGA_LICENSE_TRIAL.md ni o‘qing. Test flaglarini release config’dan olib tashlang.')
print('PASS: billing configuration present. Google Play product, backend and real-device purchase still require validation.')
