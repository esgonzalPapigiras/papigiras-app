import 'dart:async';

mixin Validators {
  final validarPass = StreamTransformer<String, String>.fromHandlers(
    handleData: (password, sink) {
      if (password.length >= 6) {
        sink.add(password);
      } else {
        sink.addError('La contraseña debe tener al menos 6 caracteres.');
      }
    },
  );

  final validarCorreo = StreamTransformer<String, String>.fromHandlers(
    handleData: (correo, sink) {
      final pattern = r'^[^<>()[\]\\.,;:\s@"]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
      final regExp = RegExp(pattern);

      if (regExp.hasMatch(correo)) {
        sink.add(correo);
      } else {
        sink.addError('Escribir un correo válido.');
      }
    },
  );

  final validarRut = StreamTransformer<String, String>.fromHandlers(
    handleData: (rut, sink) {
      final pattern = r'^\d{1,2}\.\d{3}\.\d{3}-[\dkK]$';
      final regExp = RegExp(pattern);

      if (regExp.hasMatch(rut)) {
        sink.add(rut);
      } else {
        sink.addError('Escribir un RUT válido (ejemplo: 12.345.678-K).');
      }
    },
  );
}
