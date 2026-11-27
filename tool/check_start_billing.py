"""Check the configuration required to accept a new Core purchase."""
import base64
import json
import pathlib
import sys
from urllib.parse import urlsplit

root = pathlib.Path(__file__).resolve().parents[1]
try:
    config = json.loads((root / 'billing_config.json').read_text())
except (OSError, ValueError):
    sys.exit('STOP: billing_config.json faylini sozlang. backend/purchase_verifier/README.md ni o‘qing.')

if not isinstance(config, dict):
    sys.exit('STOP: billing_config.json JSON obyekt bo‘lishi kerak.')

try:
    raw = base64.b64decode(config['BILGA_PLAY_LICENSE_KEY'], validate=True)
    if len(raw) < 200 or raw[0] != 0x30:
        raise ValueError
except (ValueError, KeyError, TypeError):
    sys.exit('STOP: billing_config.json ichiga haqiqiy Google Play public licensing key kiriting. PLAY_PRODUCTS_1_3.md ni o‘qing.')

try:
    url = config['BILGA_BILLING_VERIFY_URL']
    endpoint = urlsplit(url)
    if (endpoint.scheme != 'https' or not endpoint.hostname or
            endpoint.username is not None or endpoint.fragment or
            any(character.isspace() for character in url) or
            endpoint.port == 0):
        raise ValueError
    grant_key = base64.b64decode(config['BILGA_BILLING_VERIFY_KEY'], validate=True)
    if len(grant_key) != 32:
        raise ValueError
except (AttributeError, ValueError, KeyError, TypeError):
    sys.exit('STOP: BILGA_BILLING_VERIFY_URL va BILGA_BILLING_VERIFY_KEY qiymatlarini sozlang. backend/purchase_verifier/README.md ni o‘qing.')

if config.get('BILGA_TURBO_INCLUDED') in (True, 'true'):
    engine = (root / 'lib/features/agent/turbo_engine.dart').read_text()
    if 'package:llama_flutter_android' not in engine:
        sys.exit('STOP: Turbo savdosi uchun mahalliy modul kerak.')
if config.get('BILGA_AGENT_PREVIEW'):
    sys.exit('STOP: BILGA_AGENT_PREVIEW qiymatini billing_config.json faylidan olib tashlang.')

print('PASS: Play billing configuration is present. Verify purchases and restores in the Play test track.')
