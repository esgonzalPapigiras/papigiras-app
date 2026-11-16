#!/usr/bin/env python3
"""INT-001: verify the generated debug APK locally; never sign/install/upload."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk', type=Path)
parser.add_argument('--report', type=Path)
args = parser.parse_args()
apk = args.apk.resolve()
tools = Path(os.environ.get('PAPIGIRAS_TOOLS', '/Users/camiloyaneznorris/Developer/papigiras-tools'))
bin_dir = tools / 'android-sdk/build-tools/36.0.0'
env = dict(os.environ, JAVA_HOME=str(tools / 'jdk-17/amazon-corretto-17.jdk/Contents/Home'))

def run(name, *parameters):
    return subprocess.run([str(bin_dir / name), *parameters], env=env, text=True, capture_output=True, check=True).stdout

badging = run('aapt', 'dump', 'badging', str(apk))
package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
if not package or package.group(1) != 'com.papigiras.lab':
    raise SystemExit('Unexpected APK identifier; expected independent LAB package.')
if 'application-debuggable' not in badging:
    raise SystemExit('Expected development APK, not a production package.')
signature = run('apksigner', 'verify', '--verbose', str(apk))
run('zipalign', '-c', '-P', '16', '4', str(apk))
spec = importlib.util.spec_from_file_location('elf_check', Path(__file__).with_name('check_android_16kb.py'))
elf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(elf)
libraries = []
with zipfile.ZipFile(apk) as archive:
    for name in sorted(archive.namelist()):
        if name.startswith('lib/') and name.endswith('.so'):
            result = elf.inspect_elf(archive.read(name))
            libraries.append({'path': name, **result})
required = [item for item in libraries if item['bits'] == 64]
passed = bool(required) and all(item['load_alignment_pass'] and item['relro_page_pass'] for item in required)
report = {
    'artifact': apk.name,
    'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
    'size_bytes': apk.stat().st_size,
    'application_id': package.group(1),
    'version_code': package.group(2),
    'version_name': package.group(3),
    'minimum_android_api': int(re.search(r"^sdkVersion:'(\d+)'", badging, re.M).group(1)),
    'target_android_api': int(re.search(r"^targetSdkVersion:'(\d+)'", badging, re.M).group(1)),
    'debuggable': True,
    'signature_valid': True,
    'signature_schemes': signature.strip().splitlines(),
    'zipalign_16kb_pass': True,
    'libraries': libraries,
    'libraries_64bit': len(required),
    'structural_16kb_pass': passed,
    'runtime_android_tested': False,
    'limitations': ['Requires Mac with synthetic API and USB adb reverse8084 to18084.', 'Not Google Play release; no distribution signing or upload.', 'Structural16KB check is not a physical16KB runtime test.'],
}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({key: value for key, value in report.items() if key not in ('libraries', 'signature_schemes')}, indent=2))
raise SystemExit(0 if passed else 1)
