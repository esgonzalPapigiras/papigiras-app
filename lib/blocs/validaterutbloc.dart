import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'Validator.dart';

class ValidateBloc2 with Validators {
  final _rutController = BehaviorSubject<String>();
  final _correoController = BehaviorSubject<String>();

  Stream<String> get rutStream => _rutController.stream.transform(validarRut);
  Stream<String> get correoStream =>
      _correoController.stream.transform(validarcorreo);

  Stream<bool> get formValidator =>
      CombineLatestStream.combine2(rutStream, correoStream, (a, b) => true);

  Function(String) get changerut => _rutController.sink.add;
  Function(String) get changeemail => _correoController.sink.add;

  String get rut => _rutController.value;
  String get correo => _correoController.value;

  dispose() {
    _rutController?.close();
    _correoController?.close();
  }
}
