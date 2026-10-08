#!/usr/bin/env python3
"""Explicit developer-only opt-in. Default release intentionally excludes native AI."""
from pathlib import Path
import shutil
r=Path(__file__).resolve().parents[1]
p=r/'pubspec.yaml';s=p.read_text()
if 'llama_flutter_android:' not in s:
    s=s.replace('dependencies:\n','dependencies:\n  llama_flutter_android:\n    path: vendor/llama_flutter_android\n',1)
    p.write_text(s)
for name in ['turbo_engine.dart','turbo_page.dart']:
    shutil.copy2(r/'optional/turbo'/name,r/'lib/features/agent'/name)
print('Optional native AI enabled. Run flutter pub get. Device validation required before enabling BILGA_TURBO_INCLUDED in a release.')
