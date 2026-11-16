#!/usr/bin/env python3
"""Checks the isolated local-server LAB contract before launching. No network requests."""
import json
import re
import subprocess
import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parents[1]
errors = []
def require(condition, message):
    if not condition:
        errors.append(message)

pubspec = (root / 'pubspec.yaml').read_text()
# Flutter SDK localization: bundled strings only; no network/native transport.
allowed = {'flutter', 'flutter_localizations', 'cupertino_icons', 'intl', 'font_awesome_flutter', 'provider',
           'quickalert', 'rxdart', 'photo_view', 'qr_flutter', 'flutter_test',
           'flutter_map', 'flutter_map_marker_popup', 'latlong2', 'http',
           'vector_map_tiles', 'vector_tile_renderer',
           'image_picker', 'path_provider', 'path_provider_android', 'path_provider_foundation', 'share_plus', 'flutter_pdfview',
           'qr_code_scanner_plus', 'gal', 'shared_preferences', 'file_picker',
           'flutter_image_compress', 'zxing2', 'integration_test', 'record', 'audioplayers'}
require('  flutter_localizations:\n    sdk: flutter' in pubspec, 'La localización debe proceder del SDK Flutter local.')
section = pubspec.split('dependencies:', 1)[1].split('\nflutter:', 1)[0]
deps = set(re.findall(r'^  ([a-z_]+):', section, re.M))
require(deps <= allowed, 'Una dependencia nueva requiere revisar el aislamiento: ' + str(deps - allowed))
plugins = root / '.flutter-plugins-dependencies'
if plugins.exists():
    data = json.loads(plugins.read_text())
    native_allowed = {
        'file_picker', 'flutter_image_compress_common', 'flutter_pdfview', 'gal',
        'image_picker_ios', 'image_picker_android', 'path_provider_foundation',
        'path_provider_android', 'qr_code_scanner_plus', 'share_plus',
        'shared_preferences_foundation', 'shared_preferences_android',
        'flutter_plugin_android_lifecycle', 'integration_test',
        'record_android', 'record_ios', 'audioplayers_android', 'audioplayers_darwin',
    }
    for platform in ['ios', 'android']:
        actual = {item['name'] for item in data.get('plugins', {}).get(platform, [])}
        require(actual <= native_allowed, 'Plugin nativo no revisado: ' + str(actual - native_allowed))
main = (root / 'lib/main.dart').read_text()
require('HttpOverrides.global = LabOfflineHttpOverrides();' in main, 'Falta el bloqueo HTTP al iniciar.')
offline = (root / 'lib/lab/offline.dart').read_text()
require('throw const SocketException' in offline, 'Falta el rechazo de clientes HTTP.')
for f in (root / 'lib').rglob('*.dart'):
    text = f.read_text()
    relative = str(f.relative_to(root))
    if relative not in {'lib/lab/map_tiles.dart', 'lib/lab/api_http.dart'}:
        require(not re.search(r'https?://|wss?://', text), 'URL de red en ' + relative)
        require('NetworkTileProvider(' not in text and ("package:http/" not in text or relative == 'lib/provider/coordinatorProvider.dart') and 'createHttpClient(null)' not in text,
                'Transporte fuera de adaptadores revisados en ' + relative)
    require(not re.search(r'\b(?:UrlSource|setSourceUrl)\s*\(', text), 'Audio remoto no autorizado en ' + relative)
    require('NetworkImage(' not in text and 'Image.network(' not in text, 'Las imágenes deben llegar en bytes por la API local: ' + relative)
    if 'PDFView(' in text:
        require(text.count('PDFView(') == text.count('preventLinkNavigation: true'), 'El visor PDF debe bloquear navegación de enlaces: ' + relative)
    raster_layers = len(re.findall(r'(?<![A-Za-z_])TileLayer\(', text))
    if raster_layers:
        require(raster_layers == text.count('tileProvider: LabMapTiles.provider()'), 'Capa sin transporte restringido en ' + relative)
    require('NetworkVectorTileProvider(' not in text and 'StyleReader(' not in text, 'Carga vectorial fuera del transporte revisado en ' + relative)
    if 'VectorTileLayer(' in text:
        require(relative == 'lib/lab/map_basemap.dart', 'La base vectorial debe usar el adaptador revisado: ' + relative)
    if relative == 'lib/auth/saved_credentials.dart':
        text = text.replace("MethodChannel('com.papigiras.lab/credentials')", '')
    require(not re.search(r'\b(?:Socket|WebSocket|RawSocket|SecureSocket|Process)\s*\.|dart:ffi|MethodChannel|BasicMessageChannel', text), 'Acceso externo/nativo en ' + relative)
    imports = re.findall(r"(?:import|export) ['\"]package:([^/]+)/", text)
    require(set(imports) <= allowed | {'papigiras_app'}, 'Importación no revisada en ' + relative)
map_adapter = (root / 'lib/lab/map_tiles.dart').read_text()
expected_urls = {
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Navigation_Charts/MapServer/tile/{z}/{y}/{x}',
    'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
    'https://tiles.openfreemap.org/planet',
}
# Match quoted URL constants, including literal {z}/{y}/{x} placeholders.
actual_urls = set(re.findall(r"'(https://[^']+)'", map_adapter))
require(actual_urls == expected_urls, 'Los destinos cartográficos deben coincidir con Esri legado y OpenFreeMap revisados.')
require('followRedirects = false' in map_adapter and 'LabMapTiles.permits(request.method, request.url)' in map_adapter,
        'Falta la restricción de solicitudes o redirecciones del mapa.')
for local_style in ('positron.json', 'pilo.json'):
    map_style = json.loads((root / 'assets/maps' / local_style).read_text())
    require(not re.search(r'https?://', json.dumps(map_style)), 'El estilo local no puede incluir destinos de red.')
    require('glyphs' not in map_style and 'sprite' not in map_style, 'Glifos y sprites deben permanecer locales.')
    require(map_style.get('sources') == {'openmaptiles': {'type': 'vector'}}, 'Fuentes de estilo distintas de las revisadas.')
basemap = (root / 'lib/lab/map_basemap.dart').read_text()
require('LabMapTiles.readOpenMapVersion(_client)' in basemap and 'LabOpenMapTileProvider.vector(' in basemap, 'Falta el proveedor vectorial limitado.')
api_adapter = (root / 'lib/lab/api_http.dart').read_text()
require("Uri.http('127.0.0.1:$localPort'" in api_adapter and "uri.host == '127.0.0.1'" in api_adapter and 'uri.port == localPort' in api_adapter
        and 'const {8084, 18084}.contains(localPort)' in api_adapter and 'if (!_validPort) throw StateError' in api_adapter
        and 'defaultValue: 8084' in api_adapter and "'PAPIGIRAS_LOCAL_API_PORT'" in api_adapter,
        'La API debe restringirse al servidor LAB local.')
require('request.followRedirects = false' in api_adapter and 'LabApi.permits(request.method, request.url)' in api_adapter,
        'Falta la validación de solicitudes/redirecciones de la API.')
require("String.fromEnvironment('PAPIGIRAS_PREVIEW_HOST')" in api_adapter and
        "uri.host == previewHost" in api_adapter and "uri.port == 443" in api_adapter and
        "uri.scheme == 'https'" in api_adapter and "_validPreviewHost" in api_adapter,
        'La beta debe restringirse al host HTTPS exacto elegido al compilar.')
mode = (root / 'lib/lab/mode.dart').read_text()
require('static bool _fixturesForTests = false;' in mode, 'Los fixtures no pueden ser el modo de ejecución por defecto.')
for path in (root / 'lib').rglob('*.dart'):
    if path.name != 'mode.dart':
        require('useFixturesForTests(' not in path.read_text(), 'Los fixtures se habilitan solo en tests.')
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
ids = re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', project)
require(bool(ids) and set(ids) <= {'com.papigiras.lab', 'com.papigiras.lab.RunnerTests'}, 'Identificador iOS ajeno al LAB.')
require('DEVELOPMENT_TEAM =' not in project, 'El LAB no necesita un equipo de firma de distribución.')
info = (root / 'ios/Runner/Info.plist').read_text()
require('Papigiras LAB' in info, 'Falta el nombre visible LAB.')
native_info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
usage_keys = {key for key in native_info if key.endswith('UsageDescription')}
require(usage_keys <= {'NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSPhotoLibraryAddUsageDescription', 'NSMicrophoneUsageDescription', 'NSFaceIDUsageDescription'}, 'Permiso iOS ajeno a cámara/fotos/micrófono y al acceso a la clave local.')
credentials_bridge = (root / 'ios/Runner/AppDelegate.swift').read_text()
require('kSecAttrAccessibleWhenUnlockedThisDeviceOnly' in credentials_bridge and 'kSecAttrSynchronizable' not in credentials_bridge,
        'Las credenciales de Pilo deben quedar cifradas en el llavero, accesibles con el dispositivo desbloqueado y sin sincronización.')
require('UIBackgroundModes' not in native_info, 'No habilitar GPS/push/segundo plano nativo en LAB.')
android_ns = '{http://schemas.android.com/apk/res/android}'
for manifest_file in (root / 'android/app/src').glob('*/AndroidManifest.xml'):
    native_manifest = ET.parse(manifest_file).getroot()
    for permission in native_manifest.findall('uses-permission'):
        name = permission.attrib[android_ns + 'name']
        require(name in {'android.permission.INTERNET', 'android.permission.CAMERA', 'android.permission.WRITE_EXTERNAL_STORAGE', 'android.permission.RECORD_AUDIO'}, 'Permiso Android ajeno al LAB: ' + name)
        if name == 'android.permission.WRITE_EXTERNAL_STORAGE':
            require(permission.attrib.get(android_ns + 'maxSdkVersion') == '29', 'Almacenamiento solo API29 o anterior para guardar fotos.')
for base in [root / 'lib', root / 'ios', root / 'android', root / 'assets']:
    for f in base.rglob('*'):
        if not f.is_file() or any(x in f.parts for x in ['Pods', '.symlinks', 'ephemeral', '.gradle', '.cxx', 'build']):
            continue
        require(f.name not in {'GoogleService-Info.plist', 'google-services.json', 'firebase_options.dart', '.env'} and f.suffix not in {'.p12', '.mobileprovision', '.jks', '.keystore'}, 'Configuración real o firma inesperada: ' + str(f.relative_to(root)))
if (root / '.git').exists():
    remotes = subprocess.run(['git', '-C', str(root), 'remote'], capture_output=True, text=True, check=True).stdout.strip()
    if remotes:
        origin = subprocess.run(['git', '-C', str(root), 'remote', 'get-url', 'origin'], capture_output=True, text=True, check=True).stdout.strip()
        branch = subprocess.run(['git', '-C', str(root), 'branch', '--show-current'], capture_output=True, text=True, check=True).stdout.strip()
        require(remotes == 'origin' and origin == 'https://github.com/esgonzalPapigiras/papigiras-app.git' and branch == 'revision/pilo-2026-11-16', 'Sólo se autoriza el remoto y la rama de revisión de esta entrega.')
if errors:
    raise SystemExit('LAB BLOQUEADO:\n- ' + '\n- '.join(errors))
print('LAB OK: datos locales autorizados; tests sintéticos; HTTP general bloqueado; API local127.0.0.1 con puerto8084 o QA18084 fijado al compilar y cartografía pública revisada Esri/OpenFreeMap; sin GPS/push real; remoto Git de revisión autorizado; plugins locales de cámara/fotos/PDF/QR/preferencias y audio autorizados; grabación sólo por acción explícita.')
