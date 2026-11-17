"""The owner authorized foreground push-to-talk on November 17, 2026."""
ANDROID='{http://schemas.android.com/apk/res/android}'

def verify_voice(root):
    permissions=[n for n in root if n.tag.startswith('uses-permission')]
    names=[n.get(ANDROID+'name') for n in permissions]
    if any(n in names for n in ['android.permission.FOREGROUND_SERVICE_MICROPHONE','android.permission.CAPTURE_AUDIO_OUTPUT']):
        raise ValueError('Background/system audio capture is not authorized')
    microphones=[n for n in permissions if n.get(ANDROID+'name')=='android.permission.RECORD_AUDIO']
    if not microphones:
        return 'microphone absent (historical non-voice artifact)'
    app=root.find('application')
    mode=None if app is None else app.find(f"meta-data[@{ANDROID}name='bilga.voice.mode']")
    if len(microphones)!=1 or microphones[0].tag!='uses-permission' or mode is None or mode.get(ANDROID+'value')!='push_to_talk':
        raise ValueError('Microphone requires explicit push-to-talk scope metadata')
    if root.find(f"queries/intent/action[@{ANDROID}name='android.speech.RecognitionService']") is None:
        raise ValueError('Speech recognizer package query is missing')
    for service in app.findall('service'):
        if 'microphone' in service.get(ANDROID+'foregroundServiceType','').split('|'):
            raise ValueError('A microphone foreground service is not authorized')
    return 'authorized foreground push-to-talk; no background microphone service'
