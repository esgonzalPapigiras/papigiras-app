import 'package:flutter/material.dart';
import 'package:papigiras_app/blocs/addUserbloc.dart';
import 'package:papigiras_app/blocs/loginbloc.dart';
import 'package:papigiras_app/blocs/validaterutbloc.dart';

class Provider extends InheritedWidget {
  final loginbloc = LoginBloc();
  final validatebloc = ValidateBloc2();
  final registerbloc = AddUserBloc();

  Provider({Key? key, required Widget child}) : super(key: key, child: child);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static LoginBloc of(BuildContext context) {
    return (context.dependOnInheritedWidgetOfExactType<Provider>() as Provider)
        .loginbloc;
  }

  static ValidateBloc2 o(BuildContext context) {
    return (context.dependOnInheritedWidgetOfExactType<Provider>() as Provider)
        .validatebloc;
  }

  static AddUserBloc add(BuildContext context) {
    return (context.dependOnInheritedWidgetOfExactType<Provider>() as Provider)
        .registerbloc;
  }
}
