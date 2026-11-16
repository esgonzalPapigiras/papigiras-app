import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/voice/trip_voice_recorder.dart';
import 'package:papigiras_app/voice/voice_note_draft.dart';
import 'package:papigiras_app/voice/voice_recorder_port.dart';

class FakeRecorder implements VoiceRecorderPort {
  int permissions = 0, starts = 0, stops = 0, cancels = 0, discards = 0;
  bool allowed = true, failStop = false;
  Completer<bool>? permissionGate;
  Completer<void>? startGate;
  Completer<VoiceNoteDraft?>? stopGate;
  VoidCallback? limit, interruption;
  final draft = VoiceNoteDraft(
    file: XFile('/private/tmp/synthetic-voice-never-read.wav'),
    duration: const Duration(seconds: 3),
    byteLength: 96044,
  );
  @override
  Future<bool> requestPermission() async {
    permissions++;
    return permissionGate?.future ?? allowed;
  }

  @override
  Future<void> start({
    required VoidCallback onLimitReached,
    required VoidCallback onInterrupted,
  }) async {
    starts++;
    limit = onLimitReached;
    interruption = onInterrupted;
    await startGate?.future;
  }

  @override
  Future<VoiceNoteDraft?> stop() async {
    stops++;
    if (failStop) throw StateError('technical');
    return stopGate?.future ?? draft;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> discard(VoiceNoteDraft draft) async {
    discards++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeRecorder recorder;
  VoiceNoteDraft? value;
  var working = false;
  setUp(() {
    recorder = FakeRecorder();
    value = null;
    working = false;
  });
  Future<void> show(
    WidgetTester tester, {
    bool enabled = true,
    double scale = 1,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: StatefulBuilder(
              builder: (context, setState) => TripVoiceRecorder(
                value: value,
                recorder: recorder,
                enabled: enabled,
                previewBuilder: (_) => const Text('Vista previa ficticia'),
                onChanged: (draft) => setState(() => value = draft),
                onRecordingChanged: (active) => working = active,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('voice-record')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'permiso sólo tras tocar y rechazo no inicia captura ni muestra datos técnicos',
    (tester) async {
      recorder.allowed = false;
      await show(tester);
      expect(recorder.permissions, 0);
      expect(recorder.starts, 0);
      await start(tester);
      expect(recorder.permissions, 1);
      expect(recorder.starts, 0);
      expect(
        find.textContaining('Permite el acceso al micrófono'),
        findsOneWidget,
      );
      expect(working, isFalse);
      expect(value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detener guarda una vez y eliminar descarta el borrador', (
    tester,
  ) async {
    await show(tester);
    await start(tester);
    expect(working, isTrue);
    await tester.tap(find.byKey(const ValueKey('voice-stop')));
    await tester.pumpAndSettle();
    expect(recorder.stops, 1);
    expect(value, same(recorder.draft));
    expect(working, isFalse);
    expect(find.text('Vista previa ficticia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voice-discard')));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(recorder.discards, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timer a60segundos detiene automáticamente sin pedir otra acción',
    (tester) async {
      await show(tester);
      await start(tester);
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(recorder.stops, 1);
      expect(value, same(recorder.draft));
      expect(working, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'límite debytes ytimer no disparan dos finalizaciones simultáneas',
    (tester) async {
      recorder.stopGate = Completer<VoiceNoteDraft?>();
      await show(tester);
      await start(tester);
      recorder.limit!();
      await tester.pump();
      recorder.limit!();
      await tester.pump(const Duration(seconds: 60));
      expect(recorder.stops, 1);
      expect(find.byKey(const ValueKey('voice-stop')), findsNothing);
      recorder.stopGate!.complete(recorder.draft);
      await tester.pumpAndSettle();
      expect(value, same(recorder.draft));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permiso puede interrumpir la app; captura real se cancela al salir sin reanudarse',
    (tester) async {
      recorder.permissionGate = Completer<bool>();
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('voice-record')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(recorder.cancels, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      recorder.permissionGate!.complete(true);
      await tester.pumpAndSettle();
      expect(recorder.starts, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(recorder.cancels, 1);
      expect(value, isNull);
      expect(working, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(recorder.starts, 1);
      expect(find.textContaining('se detuvo al salir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permiso concedido después de cerrar no inicia grabación', (
    tester,
  ) async {
    recorder.permissionGate = Completer<bool>();
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('voice-record')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    recorder.permissionGate!.complete(true);
    await tester.pumpAndSettle();
    expect(recorder.starts, 0);
    expect(recorder.cancels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inicio tardío después de cerrar se cancela sin conservar muestras',
    (tester) async {
      recorder.startGate = Completer<void>();
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('voice-record')));
      await tester.pump();
      expect(recorder.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      recorder.startGate!.complete();
      await tester.pumpAndSettle();
      expect(recorder.cancels, greaterThan(0));
      expect(value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'error de guardado permite grabar de nuevo y no filtra excepciones',
    (tester) async {
      recorder.failStop = true;
      await show(tester);
      await start(tester);
      await tester.tap(find.byKey(const ValueKey('voice-stop')));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.textContaining('No pudimos guardar'), findsOneWidget);
      expect(find.textContaining('technical'), findsNothing);
      recorder.failStop = false;
      await start(tester);
      await tester.tap(find.byKey(const ValueKey('voice-stop')));
      await tester.pumpAndSettle();
      expect(recorder.starts, 2);
      expect(value, same(recorder.draft));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deshabilitado y texto ampliado conservan controles legibles sin activar micrófono',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, enabled: false, scale: 1.6);
      await tester.tap(find.byKey(const ValueKey('voice-record')));
      await tester.pump();
      expect(recorder.permissions, 0);
      expect(recorder.starts, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
