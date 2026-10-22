#!/usr/bin/env python3
"""Generate only native To-Do resource labels from the app's 43 JSON catalogs."""
import json,pathlib,html
mapping={'widget':'widgetTodo','todos':'todos','task':'task','new':'newTask','done':'reminderDone','snooze':'reminderSnooze','empty':'empty','reminders':'reminderSettings','limits':'reminderLimits','custom':'snoozeCustom','save':'save','cancel':'cancel','future':'reminderFuture'}
for p in pathlib.Path('assets/i18n').glob('*.json'):
 data=json.loads(p.read_text())
 directories=[f"values-{'iw' if p.stem=='he' else p.stem}"]+(['values'] if p.stem=='en' else [])
 for directory in directories:
  root=pathlib.Path('android/app/src/main/res')/directory;root.mkdir(exist_ok=True)
  content=['<?xml version="1.0" encoding="utf-8"?>','<resources>']
  for name,key in mapping.items():
   value=html.escape(data[key],quote=False).replace("'",r"\'").replace('"',r'\"')
   content.append(f'    <string name="tw_{name}">{value}</string>')
  (root/'todo_strings.xml').write_text('\n'.join(content+['</resources>','']))
