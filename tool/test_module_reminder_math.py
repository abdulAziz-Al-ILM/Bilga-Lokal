"""Compile pure Android reminder calendar policy with the existing JDK."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
java = Path(os.environ['JAVA_HOME']) / 'bin' if os.environ.get('JAVA_HOME') else None
if java is None:
    javac = shutil.which('javac')
    if javac:
        java = Path(javac).resolve().parent
    else:
        candidates = list((root / '.bilga-tools/java').glob('jdk-*/bin'))
        if len(candidates) != 1:
            raise SystemExit('Use the existing JDK21; no machine installation needed')
        java = candidates[0]
with tempfile.TemporaryDirectory(prefix='bilga-module-calendar-') as output:
    subprocess.run([str(java / 'javac'), '-d', output,
                    str(root / 'android/app/src/main/java/com/ilmmizan/bilga/ModuleReminderMath.java'),
                    str(root / 'tool/ModuleReminderMathCheck.java')], check=True)
    subprocess.run([str(java / 'java'), '-ea', '-cp', output,
                    'ModuleReminderMathCheck'], check=True)
