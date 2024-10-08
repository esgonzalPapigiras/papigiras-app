import 'dart:async';

class Validators {
  final validarPass = StreamTransformer<String, String>.fromHandlers(
      handleData: (password, sink) {
    if (password.length >= 6) {
      sink.add(password);
    } else {
      sink.addError('Escribir su contraseña nuevamente');
    }
  });

  final validarcredencial = StreamTransformer<String, String>.fromHandlers(
      handleData: (password, sink) {
    if (password.length >= 1) {
      sink.add(password);
    } else {
      sink.addError('Escribir sus Nombres y Apellidos');
    }
  });

  final validarcorreo = StreamTransformer<String, String>.fromHandlers(
      handleData: (correo, sink) {
    Pattern pattern =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(pattern.toString());

    if (regExp.hasMatch(correo)) {
      sink.add(correo);
    } else {
      sink.addError('Escribir correo valido');
    }
  });

  final validarRut =
      StreamTransformer<String, String>.fromHandlers(handleData: (rut, sink) {
    Pattern pattern = r'^([0-9]+-[0-9K])$';
    RegExp regExp = new RegExp(pattern.toString());

    if (regExp.hasMatch(rut)) {
      sink.add(rut);
    } else {
      sink.addError('Escribir rut valido');
    }
  });
}
