"""Guard the owner's deferred voice scope in executable first-party source."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
forbidden = re.compile(r'\b(?:TextToSpeech|SpeechRecognizer|RecognizerIntent)\b|android\.permission\.RECORD_AUDIO|package:(?:speech_to_text|flutter_tts)/')
violations = []
for directory in ('lib', 'android/app/src/main'):
    for path in (root / directory).rglob('*'):
        if path.suffix not in {'.dart', '.kt', '.java', '.xml'}:
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if forbidden.search(line):
                violations.append(f'{path.relative_to(root)}:{number}')
if violations:
    raise SystemExit('Deferred voice API or microphone permission found: ' + ', '.join(violations))
print('PASS no deferred voice APIs or microphone permission in executable first-party source')
