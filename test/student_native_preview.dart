// Isolated native QA entrypoint. Never used by main.dart or normal Pilo builds.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/lab/preferences.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class _NoNetwork extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw StateError('Network is disabled in student native QA');
}

class _NativeFixtureProvider extends CoordinatorProviders {
  _NativeFixtureProvider()
    : super(client: LabApiClient(transport: _NoNetwork()));

  @override
  Future<PassengersMedicalRecordDTO> getMedicalRecord(
    String tour,
    String passenger,
  ) async => PassengersMedicalRecordDTO.fromJson({
    'idPassengersMedicalRecord': 910011,
    'passengerId': 910011,
    'tourSalesId': 910001,
    'contactoEmergenciaNombre': 'Contacto Ejemplo',
    'contactoEmergenciaTelefono': '+56 9 0000 0000',
    'contactoEmergenciaRelacion': 'Apoderado',
  });

  @override
  Future<Responseimagepassenger> getPicturePassenger(
    String rut,
    String tour,
  ) async => Responseimagepassenger(image: '');

  @override
  Future<Uint8List> getMedicalRecordPdf(String tour, String passenger) async =>
      _pdf();
}

Uint8List _pdf() {
  const content =
      'BT /F1 20 Tf 40 480 Td (PAPIGIRAS LAB - QA) Tj '
      '0 -50 Td /F1 14 Tf (Documento PDF sintetico) Tj '
      '0 -30 Td (Solo validacion de render nativo.) Tj '
      '0 -30 Td (Sin informacion medica real.) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
  ];
  var result = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(result.length);
    result += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final start = result.length;
  result += 'xref\n0 6\n0000000000 65535 f \n';
  for (final offset in offsets) {
    result += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  result += 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n';
  return Uint8List.fromList(ascii.encode(result));
}

const _requestedAction = String.fromEnvironment('STUDENT_NATIVE_QA_ACTION');
final _reportFacts = <String, Object?>{
  'changeId': 'PILO-ALUMNO-FICHA-COMPARTIR',
  'fixtureOnly': true,
  'networkEnabled': false,
  'pdfSource': 'synthetic-local',
  'nativePdfRendered': false,
  'requestedAction': _requestedAction,
};
Future<void> _reportQueue = Future<void>.value();

Future<void> _report(String status, {Map<String, Object?> facts = const {}}) {
  _reportFacts.addAll(facts);
  _reportFacts['status'] = status;
  final encoded = jsonEncode(_reportFacts);
  // Serialize writes so an earlier status cannot overwrite the rendered result.
  _reportQueue = _reportQueue.then((_) async {
    await File(
      '${Directory.systemTemp.path}/student-native-report.json',
    ).writeAsString(encoded);
  });
  return _reportQueue;
}

void main() async {
  if (!const bool.fromEnvironment('STUDENT_NATIVE_QA')) {
    throw StateError('This entrypoint requires STUDENT_NATIVE_QA=true');
  }
  if (!const ['', 'share', 'download'].contains(_requestedAction)) {
    throw StateError('STUDENT_NATIVE_QA_ACTION must be share or download');
  }
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(_report('flutter_error', facts: {'flutterErrorObserved': true}));
    previous?.call(details);
  };
  await _report('started');
  runApp(const _NativePreview());
}

class _NativePreview extends StatefulWidget {
  const _NativePreview();
  @override
  State<_NativePreview> createState() => _NativePreviewState();
}

class _NativePreviewState extends State<_NativePreview> {
  final _provider = _NativeFixtureProvider();
  final _tree = GlobalKey();
  Timer? _home;
  Timer? _open;
  Timer? _poll;
  Timer? _action;

  Iterable<Element> _elements() sync* {
    final context = _tree.currentContext;
    if (context == null) return;
    final result = <Element>[];
    void visit(Element element) {
      result.add(element);
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    yield* result;
  }

  Iterable<Widget> _widgets() => _elements().map((element) => element.widget);

  Map<String, Object?> _homeFacts() {
    final texts = _widgets().whereType<Text>().map((text) => text.data);
    return {
      'homeEmergencyContactsVisible': texts.any(
        (text) => const {
          'Contactos de emergencia',
          'Contacto de emergencia',
          'Contacto Ejemplo',
          '+56 9 0000 0000',
        }.contains(text),
      ),
      'homeMedicalActionPresent': _widgets().any(
        (widget) => widget.key == const ValueKey('student-medical-open'),
      ),
    };
  }

  Map<String, Object?> _pdfFacts() {
    final facts = <String, Object?>{
      'nativePdfRendered': true,
      'editableFieldsPresent': _widgets().any(
        (widget) => widget is EditableText || widget is TextFormField,
      ),
    };
    for (final action in ['share', 'download']) {
      final elements = _elements().where(
        (element) => element.widget.key == ValueKey('student-medical-$action'),
      );
      final element = elements.isEmpty ? null : elements.first;
      final widget = element?.widget;
      final render = element?.findRenderObject();
      var visible = false;
      if (element != null && render is RenderBox && render.hasSize) {
        final rect = render.localToGlobal(Offset.zero) & render.size;
        final screen = MediaQuery.sizeOf(element);
        visible =
            !rect.isEmpty &&
            rect.left >= 0 &&
            rect.top >= 0 &&
            rect.right <= screen.width &&
            rect.bottom <= screen.height;
      }
      facts['${action}ActionInTree'] = element != null;
      facts['${action}ActionEnabled'] =
          widget is ButtonStyleButton && widget.onPressed != null;
      facts['${action}ActionOnScreen'] = visible;
    }
    return facts;
  }

  void _requestNativeAction() {
    if (_requestedAction.isEmpty) return;
    _action = Timer(const Duration(seconds: 2), () {
      final buttons = _widgets().whereType<ButtonStyleButton>().where(
        (button) => button.key == ValueKey('student-medical-$_requestedAction'),
      );
      if (buttons.isEmpty || buttons.first.onPressed == null) {
        unawaited(_report('native_action_unavailable'));
        return;
      }
      buttons.first.onPressed!();
      // This opens only the native chooser. Never select a recipient, folder,
      // or save/send action. The operator verifies and dismisses the chooser.
      unawaited(
        _report(
          'native_action_requested',
          facts: {
            'nativeActionTriggered': _requestedAction,
            'nativePickerRequiresManualVerification': true,
            'destinationSelected': false,
          },
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _home = Timer(const Duration(seconds: 2), () {
      unawaited(_report('home_ready', facts: _homeFacts()));
    });
    // Leave the initial screen available for a native screenshot first.
    _open = Timer(const Duration(seconds: 10), () {
      final buttons = _widgets().whereType<FilledButton>().where(
        (button) => button.key == const ValueKey('student-medical-open'),
      );
      if (buttons.isEmpty || buttons.first.onPressed == null) {
        unawaited(_report('medical_action_unavailable'));
        return;
      }
      buttons.first.onPressed!();
      unawaited(_report('sheet_opened', facts: _homeFacts()));
      var attempts = 0;
      _poll = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        final texts = _widgets().whereType<Text>().map((text) => text.data);
        if (texts.contains('1 / 1')) {
          timer.cancel();
          unawaited(_report('rendered', facts: _pdfFacts()));
          _requestNativeAction();
        } else if (texts.contains('No pudimos abrir tu ficha médica.')) {
          timer.cancel();
          unawaited(_report('pdf_error'));
        } else if (++attempts >= 120) {
          timer.cancel();
          unawaited(_report('render_timeout'));
        }
      });
    });
  }

  @override
  void dispose() {
    _home?.cancel();
    _open?.cancel();
    _poll?.cancel();
    _action?.cancel();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: _tree,
    debugShowCheckedModeBanner: false,
    theme: PiloFamilyTheme.theme(ThemeData()),
    home: TravelPassengerDashboard(
      login: ResponseAttorney(
        passengerId: 910011,
        tourId: 910001,
        passengerName: 'SOFÍA ISABEL',
        passengerApellidos: 'TORRES EJEMPLO',
        passengerIdentificacion: 'LAB-910011',
      ),
      provider: _provider,
    ),
  );
}
