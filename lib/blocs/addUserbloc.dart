import 'dart:async';

import 'package:papigiras_app/blocs/Validator.dart';
import 'package:rxdart/rxdart.dart';

class AddUserBloc with Validators {
  final _rutController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();
  final _nombreApellidoController = BehaviorSubject<String>();
  final _correoController = BehaviorSubject<String>();

  Stream<String> get rutStream => _rutController.stream.transform(validarRut);
  Stream<String> get passwordStream =>
      _passwordController.stream.transform(validarPass);
  Stream<String> get credencialStream =>
      _nombreApellidoController.stream.transform(validarPass);
  Stream<String> get correoStream =>
      _correoController.stream.transform(validarCorreo);

  Stream<bool> get formValidator => CombineLatestStream.combine4(rutStream,
      passwordStream, credencialStream, correoStream, (a, b, c, d) => true);

  Function(String) get changerut => _rutController.sink.add;
  Function(String) get changePassword => _passwordController.sink.add;
  Function(String) get changeNombreApellido =>
      _nombreApellidoController.sink.add;
  Function(String) get changeCorreo => _correoController.sink.add;

  String get rut => _rutController.value;
  String get password => _passwordController.value;
  String get credencial => _nombreApellidoController.value;
  String get correo => _correoController.value;

  dispose() {
    _rutController?.close();
    _passwordController?.close();
    _nombreApellidoController?.close();
    _correoController?.close();
  }
}
