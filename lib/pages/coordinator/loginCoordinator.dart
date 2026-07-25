import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/alumns/indexpassenger.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';

class LoginCoordinator extends StatefulWidget {
  @override
  _LoginCoordinatorState createState() => _LoginCoordinatorState();
}

class _LoginCoordinatorState extends State<LoginCoordinator> {
  final usuarioProvider = new CoordinatorProviders();
  final TextEditingController _codigoGiraController = TextEditingController();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _codigoGiraController.addListener(() {
      setState(() {
        _showError = false;
      });
    });
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkLoginStatus();
    });
  }

  void _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedRut = prefs.getString('codigoGira');
    String? storedPassword = prefs.getString('userPassword');
    setState(() {
      if (storedRut != null) {
        _codigoGiraController.text = storedRut;
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? token = await _loadToken();
    if (isLoggedIn && token != null) {
      String? loginJson = prefs.getString('loginData');
      if (loginJson != null) {
        String role = prefs.getString('userRole') ?? '';
        var loginMap = jsonDecode(loginJson);
        if (!mounted) return;
        try {
          if (role == 'coordinator') {
            TourSales login = TourSales.fromJson(loginMap);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TravelCoordinatorDashboard(login: login)));
          } else if (role == 'passenger') {
            ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TravelPassengerDashboard(login: login)));
          } else if (role == 'father') {
            ResponseAttorney login = ResponseAttorney.fromJson(loginMap);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TravelFatherDashboard(login: login)));
          } else {
            await _clearSession(prefs);
          }
        } catch (e) {
          print("Error deserializando loginData: $e");
          await _clearSession(prefs);
        }
      } else {
        await _clearSession(prefs);
      }
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove('token');
    await prefs.remove('tokenExpiry');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('loginData');
    await prefs.remove('userRole');
  }

  Future<String?> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? tokenExpiryStr = prefs.getString('tokenExpiry');
    if (token != null && tokenExpiryStr != null) {
      DateTime tokenExpiry = DateTime.parse(tokenExpiryStr);
      final now = DateTime.now();
      if (tokenExpiry.isBefore(now)) {
        await prefs.remove('token');
        await prefs.remove('tokenExpiry');
        return null;
      } else {
        return token;
      }
    } else {
      return null;
    }
  }

  @override
  void dispose() {
    _codigoGiraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0, 5))],
                  ),
                  padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset('assets/logo-letras-papigiras.png', height: 60.0),
                      SizedBox(height: 10.0),
                      Text('Bienvenido(s)', style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                      Text('Coordinador(a)', style: TextStyle(fontSize: 16.0, color: Colors.grey[600])),
                      SizedBox(height: 30.0),
                      TextField(
                        controller: _codigoGiraController,
                        decoration: InputDecoration(
                          labelText: 'Código Gira',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _showError ? Colors.red : Colors.grey), borderRadius: BorderRadius.circular(10.0)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _showError ? Colors.red : Colors.teal), borderRadius: BorderRadius.circular(10.0)),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _showError = false;
                          });
                        },
                      ),
                      if (_showError)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text('Debes ingresar un codigo de gira', style: TextStyle(color: Colors.red, fontSize: 12.0)),
                        ),
                      SizedBox(height: 30.0),
                      ElevatedButton(
                        onPressed: () async {
                          if (_codigoGiraController.text.isNotEmpty) {
                            setState(() {
                              _showError = false;
                            });
                            final login = await usuarioProvider.validateLoginUser(_codigoGiraController.text);
                            if (login != null) {
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.success,
                                title: 'Éxito',
                                text: 'Gira encontrada',
                                confirmBtnText: 'Continuar',
                                onConfirmBtnTap: () async {
                                  SharedPreferences prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('token', login.tokenKey);
                                  final now = DateTime.now();
                                  final expiryDate = now.add(Duration(days: 3));
                                  await prefs.setString('tokenExpiry', expiryDate.toIso8601String());
                                  await prefs.setString('userRole', 'coordinator');
                                  await prefs.setBool('isLoggedIn', true);
                                  String loginJson = jsonEncode(login.toJson());
                                  await prefs.setString('loginData', loginJson);
                                  Navigator.of(context).pop();
                                  LocationPermission permission = await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                                    QuickAlert.show(
                                      context: context,
                                      type: QuickAlertType.error,
                                      title: 'Permiso denegado',
                                      text: 'Necesitamos permiso de ubicación para continuar.',
                                      confirmBtnText: 'Aceptar',
                                      onConfirmBtnTap: () => Navigator.of(context).pop(),
                                    );
                                    return;
                                  }
                                  final locationService = Provider.of<LocationService>(context, listen: false);
                                  await locationService.initializeForCoordinatorSession();
                                  if (!mounted) return;
                                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => TravelCoordinatorDashboard(login: login)), (route) => false);
                                },
                              );
                            } else {
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.error,
                                title: 'Error',
                                text: 'Gira no encontrada',
                                confirmBtnText: 'Aceptar',
                                onConfirmBtnTap: () {
                                  Navigator.of(context).pop();
                                },
                              );
                            }
                          } else {
                            setState(() {
                              _showError = true;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 15.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                          backgroundColor: Colors.teal,
                        ),
                        child: Text('Ingresar', style: TextStyle(fontSize: 18.0, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
