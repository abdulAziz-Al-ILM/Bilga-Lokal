"""Fail before a paid release when the public Google Play licensing key is absent."""
import base64
import json
import pathlib
import sys

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
except (OSError, ValueError, KeyError, TypeError):
    sys.exit('STOP: billing_config.json ichiga haqiqiy Google Play public licensing key kiriting. PLAY_PRODUCTS_1_3.md ni o‘qing.')
print('PASS: Play public key configured. Product price and purchases still require Play Console testing.')
