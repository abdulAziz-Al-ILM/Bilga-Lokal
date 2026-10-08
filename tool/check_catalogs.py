#!/usr/bin/env python3
import json,pathlib,re
root=pathlib.Path(__file__).resolve().parents[1]
base=json.loads((root/'assets/i18n/en.json').read_text())
catalogs=list((root/'assets/i18n').glob('*.json'))
assert len(catalogs)==43,len(catalogs)
for path in catalogs:
 data=json.loads(path.read_text())
 assert set(data)==set(base),path.name
 assert all(isinstance(v,str) and v.strip() for v in data.values()),path.name
 assert not any(re.match(r'^\d{3}:',v) for v in data.values()),path.name
print(f'PASS {len(catalogs)} languages × {len(base)} strings; {sum(p.stat().st_size for p in catalogs)} bytes')
