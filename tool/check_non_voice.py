"""Legacy CI entrypoint: enforce the newly authorized Nov17 voice boundaries."""
import re
from pathlib import Path
import xml.etree.ElementTree as ET
from verify_voice_scope import verify_voice
root=Path(__file__).resolve().parents[1]
allowed={'android/app/src/main/kotlin/com/ilmmizan/bilga/SpeechBridge.kt','android/app/src/main/AndroidManifest.xml'}
voice=re.compile(r'\b(?:SpeechRecognizer|RecognizerIntent)\b|android\.permission\.RECORD_AUDIO')
violations=[]
for directory in ('lib','android/app/src/main'):
 for path in (root/directory).rglob('*'):
  if path.suffix not in {'.dart','.kt','.java','.xml'}:continue
  source=path.read_text()
  if re.search(r'\bTextToSpeech\b|package:(?:speech_to_text|flutter_tts)/',source) and path.name != 'SpeechOutput.kt':violations.append(str(path.relative_to(root)))
  if voice.search(source) and str(path.relative_to(root)) not in allowed:violations.append(str(path.relative_to(root)))
if violations:raise SystemExit('Voice API outside explicit capture boundary: '+', '.join(violations))
print('PASS '+verify_voice(ET.fromstring((root/'android/app/src/main/AndroidManifest.xml').read_text())))
source=(root/'android/app/src/main/kotlin/com/ilmmizan/bilga/SpeechBridge.kt').read_text()
assert source.count('startListening(')==1
assert source.count('requestPermissions(')==1
assert source.index('"listen" ->')<source.index('requestPermissions(')<source.index('private fun onDevice')
assert 'startForegroundService' not in source and 'startService(' not in source
assert 'if(!value)cancel()' in source and 'old?.destroy()' in source
print('PASS button-gated runtime permission, one recognition start, foreground cancellation and recognizer destruction')
