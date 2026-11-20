#!/usr/bin/env python3
"""Inspect a connected Android candidate without signing, installing or uploading.

APK mode checks its cryptographic signature but does not assert it matches the
store certificate. AAB mode is explicitly unsigned. Native/device/push behavior
and Play signing are separate acceptance gates, regardless of this result.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

from check_android_16kb import inspect_elf

ANDROID = '{http://schemas.android.com/apk/res/android}'
BUNDLETOOL_SHA256 = 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29'


def run(*args):
    return subprocess.run([str(arg) for arg in args], capture_output=True,
                          text=True, encoding='utf-8', errors='replace', check=True).stdout


def aapt_manifest(text):
    """Read aapt2's indented XML tree, preserving element/attribute ownership."""
    stack = []
    root = None
    for line in text.splitlines():
        indent = len(line) - len(line.lstrip())
        content = line.strip()
        if content.startswith('E: '):
            node = ET.Element(content[3:].split()[0])
            while stack and stack[-1][0] >= indent:
                stack.pop()
            if stack:
                stack[-1][1].append(node)
            elif root is not None:
                raise ValueError('Multiple manifest roots')
            else:
                root = node
            stack.append((indent, node))
        elif content.startswith('A: '):
            if not stack:
                raise ValueError('Attribute without element')
            key, value = content[3:].split('=', 1)
            key = key.split('(')[0].replace('http://schemas.android.com/apk/res/android:', ANDROID)
            if value.startswith('"'):
                value = json.JSONDecoder().raw_decode(value)[0]
            stack[-1][1].set(key, value)
    if root is None or root.tag != 'manifest':
        raise ValueError('Missing Android manifest')
    return root


def manifest_checks(root, debug, version_code):
    app = root.find('application')
    sdk = root.find('uses-sdk')
    if app is None or sdk is None:
        raise ValueError('Missing application or SDK declaration')
    permissions = {item.get(ANDROID + 'name') for item in root.findall('uses-permission')}
    required = {'INTERNET', 'POST_NOTIFICATIONS', 'CAMERA', 'RECORD_AUDIO',
                'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'ACCESS_BACKGROUND_LOCATION',
                'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_LOCATION'}
    services = {item.get(ANDROID + 'name'): item for item in app.findall('service')}
    metadata = {item.get(ANDROID + 'name'): item.get(ANDROID + 'value') for item in app.findall('meta-data')}
    messaging = services.get('io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService')
    background = services.get('io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService')
    gps = services.get('yukams.app.background_locator_2.IsolateHolderService')
    checks = {
        'official_application_id': root.get('package') == 'com.papigiras',
        'version_code': root.get(ANDROID + 'versionCode') == str(version_code),
        'version_name': root.get(ANDROID + 'versionName') == '1.1.0',
        'official_label': app.get(ANDROID + 'label') == 'PapiGiras',
        'debug_mode_expected': (app.get(ANDROID + 'debuggable', 'false') == 'true') == debug,
        'minimum_api_25': sdk.get(ANDROID + 'minSdkVersion') == '25',
        'target_api_36': sdk.get(ANDROID + 'targetSdkVersion') == '36',
        'required_permissions': all('android.permission.' + item in permissions for item in required),
        'hito_channel': metadata.get('com.google.firebase.messaging.default_notification_channel_id') == 'hito_channel',
        'fcm_service_private': messaging is not None and messaging.get(ANDROID + 'exported') == 'false',
        'fcm_background_private': background is not None and background.get(ANDROID + 'exported') == 'false',
        'gps_service_private': gps is not None and gps.get(ANDROID + 'exported') == 'false',
        'gps_location_type': gps is not None and gps.get(ANDROID + 'foregroundServiceType') in ('location', '0x00000008'),
    }
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--kind', required=True, choices=['debug-apk', 'unsigned-release-aab'])
    parser.add_argument('--api-url', required=True)
    parser.add_argument('--version-code', required=True, type=int)
    parser.add_argument('--build-tools', type=Path, help='Android SDK build-tools directory (APK mode)')
    parser.add_argument('--java', type=Path, required=True)
    parser.add_argument('--bundletool', type=Path, help='Pinned bundletool 1.18.3 (AAB mode)')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    if not args.api_url.startswith('https://'):
        parser.error('Connected artifact requires an HTTPS API origin')
    debug = args.kind == 'debug-apk'
    os.environ['JAVA_HOME'] = str(args.java.resolve().parent.parent)
    signature = {}
    if debug:
        if not args.build_tools:
            parser.error('--build-tools is required for APKs')
        suffix = '.exe' if os.name == 'nt' else ''
        root = aapt_manifest(run(args.build_tools / ('aapt2' + suffix), 'dump', 'xmltree',
                                 '--file', 'AndroidManifest.xml', args.artifact))
        cert = run(args.build_tools / ('apksigner.bat' if os.name == 'nt' else 'apksigner'),
                   'verify', '--print-certs', args.artifact)
        hashes = re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]+)', cert)
        signature = {'signature_verified': True, 'certificate_sha256': hashes,
                     'debug_certificate': 'CN=Android Debug' in cert,
                     'matches_store_certificate': None}
        run(args.build_tools / ('zipalign' + suffix), '-c', '-P', '16', '4', args.artifact)
    else:
        if not args.bundletool or hashlib.sha256(args.bundletool.read_bytes()).hexdigest() != BUNDLETOOL_SHA256:
            parser.error('AAB mode requires the pinned official bundletool 1.18.3 checksum')
        run(args.java, '-jar', args.bundletool, 'validate', '--bundle=' + str(args.artifact))
        root = ET.fromstring(run(args.java, '-jar', args.bundletool, 'dump', 'manifest',
                                 '--bundle=' + str(args.artifact), '--module=base'))
    checks = manifest_checks(root, debug, args.version_code)
    libraries, api_entries, app_entries = [], [], []
    with zipfile.ZipFile(args.artifact) as archive:
        names = archive.namelist()
        signatures = [name for name in names if name.startswith('META-INF/') and name.upper().endswith(('.RSA', '.DSA', '.EC', '.SF'))]
        if not debug:
            checks['unsigned_expected'] = not signatures
        for name in sorted(names):
            if name.endswith('.so') and (name.startswith('lib/') or '/lib/' in name):
                libraries.append({'path': name, **inspect_elf(archive.read(name))})
            if name.endswith(('/libapp.so', '/kernel_blob.bin')):
                app_entries.append(name)
                if args.api_url.encode() in archive.read(name):
                    api_entries.append(name)
    required = [lib for lib in libraries if lib['bits'] == 64]
    checks['native_64bit_alignment'] = bool(required) and all(lib['load_alignment_pass'] and lib['relro_page_pass'] for lib in required)
    # Presence is useful build evidence, not proof of destination enforcement at runtime.
    checks['compiled_api_literal_present'] = bool(app_entries) and api_entries == app_entries
    if debug:
        checks['debug_signer_expected'] = signature['debug_certificate'] and bool(signature['certificate_sha256'])
    report = {
        'artifact': str(args.artifact.resolve()), 'kind': args.kind,
        'sha256': hashlib.sha256(args.artifact.read_bytes()).hexdigest(),
        'size_bytes': args.artifact.stat().st_size, 'api_origin_literal': args.api_url,
        'api_literal_entries': api_entries, 'checks': checks, 'signature': signature,
        'libraries': libraries, 'structural_checks_pass': all(checks.values()),
        'device_tested': False, 'push_delivery_tested': False, 'store_update_verified': False,
        'limitations': 'Manifest/ELF/compiled-literal checks only. Signing compatibility, native runtime and real notification delivery remain unverified.'
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'kind': args.kind, 'sha256': report['sha256'], 'checks': checks,
                      'signature': signature, 'structural_checks_pass': report['structural_checks_pass']}, indent=2))
    raise SystemExit(0 if report['structural_checks_pass'] else 1)


if __name__ == '__main__':
    main()
