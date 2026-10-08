#!/usr/bin/env python3
"""Validate release configuration locally; never print client IDs or secrets."""
import json
import re
import sys
from pathlib import Path

def check(path):
    try:
        value = json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        raise ValueError('google_config.json topilmadi yoki JSON xato.') from None
    if not isinstance(value, dict):
        raise ValueError('google_config.json JSON obyekt bo‘lishi kerak.')
    client_id = value.get('BILGA_GOOGLE_WEB_CLIENT_ID', '')
    if not isinstance(client_id, str) or not re.fullmatch(r'[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com', client_id):
        raise ValueError('BILGA_GOOGLE_WEB_CLIENT_ID to‘g‘ri Web OAuth client ID bo‘lishi kerak.')
    if any('secret' in key.lower() for key in value):
        raise ValueError('Client secret mobil ilovaga kiritilmaydi. Bu faylda faqat Web client ID bo‘lsin.')
    return True

if __name__ == '__main__':
    try:
        check(sys.argv[1] if len(sys.argv) > 1 else 'google_config.json')
    except ValueError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    print('PASS Google Web client ID configured. Play SHA-1 still requires Cloud registration.')
