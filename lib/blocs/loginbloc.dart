import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'Validator.dart';

class LoginBloc with Validators {
  final _emailController = BehaviorSubject<String>();
  final _passwordController = BehaviorSubject<String>();

  Stream<String> get emailStream =>
      _emailController.stream.transform(validarRut);
  Stream<String> get passwordStream =>
      _passwordController.stream.transform(validarPass);

  Stream<bool> get formValidator =>
      CombineLatestStream.combine2(emailStream, passwordStream, (a, b) => true);

  Function(String) get changeEmail => _emailController.sink.add;
  Function(String) get changePassword => _passwordController.sink.add;

  String get rut => _emailController.hasValue ? _emailController.value : "";
  String get password => _passwordController.value;

  reset() {
    _emailController.value = ""; // Limpiar el valor del email
    _passwordController.value = ""; // Limpiar el valor de la contraseña
  }

  dispose() {
    _emailController?.close();
    _passwordController?.close();
  }
}
