import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class CountDownCoordScreen extends StatefulWidget {
  final TourSales login;
  CountDownCoordScreen({required this.login});

  @override
  _CountDownCoordScreenState createState() => _CountDownCoordScreenState();
}

class _CountDownCoordScreenState extends State<CountDownCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = CoordinatorProviders();
  List<PassengerList> pasajeros = [];
  List<Map<String, dynamic>> alumnos = [];
  int totalPasajeros = 0;
  int alumnosVerificados = 0;

  @override
  void initState() {
    super.initState();
    _fetchPassengers();
  }

  Future<void> _fetchPassengers() async {
    try {
      pasajeros = await _coordinatorProvider.getListPassenger(widget.login.tourSalesId.toString());
      totalPasajeros = pasajeros.length;
      alumnosVerificados = pasajeros.where((p) => p.passengerverificate).length;
      alumnos = pasajeros.map((p) {
        return {"id": p.passengerId.toString(), "nombre": p.passengerName, "verificado": p.passengerverificate};
      }).toList();
      setState(() {});
    } catch (error) {
      print("Error al cargar los alumnos: $error");
    }
  }

  void _scanQRCode() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QRViewExample()),
    );
    if (!mounted) return;
    if (result is String && result.trim().isNotEmpty) {
      final scannedId = result.trim();
      _marcarAlumnoPorId(scannedId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se obtuvo un ID válido desde el QR.')),
      );
    }
  }

  void _resetCounter() {
    setState(() {
      alumnosVerificados = 0;
      for (var alumno in alumnos) {
        alumno["verificado"] = false;
      }
    });
  }

  void _marcarAlumnoPorId(String idEscaneado) {
    final index = alumnos.indexWhere((a) {
      final hasTourPassengerId = a.containsKey('tourPassengerId') && a['tourPassengerId'] != null;
      return hasTourPassengerId ? a['tourPassengerId'].toString() == idEscaneado : a['id'].toString() == idEscaneado;
    });
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El QR no corresponde a ningún alumno de la lista.')),
      );
      return;
    }
    if (!alumnos[index]["verificado"]) {
      setState(() {
        alumnos[index]["verificado"] = true;
        alumnosVerificados++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marcado: ${alumnos[index]["nombre"]}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${alumnos[index]["nombre"]} ya estaba verificado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kCoordinatorTeal,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              CoordinatorTopBar(login: widget.login, scaffoldKey: _scaffoldKey),
              Expanded(child: _buildContent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)));
  }

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildCounter(),
          const SizedBox(height: 20),
          Expanded(child: _buildPassengerList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text('Contador Alumnos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _scanQRCode,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
          child: const Text('Lector QR', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        TextButton(onPressed: _resetCounter, child: const Text('Reiniciar contador', style: TextStyle(color: Colors.teal))),
      ],
    );
  }

  Widget _buildCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue[200], borderRadius: BorderRadius.circular(8)),
      child: Text('$alumnosVerificados/$totalPasajeros', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPassengerList() {
    return ListView.builder(itemCount: alumnos.length, itemBuilder: (_, index) => _buildPassengerTile(index));
  }

  Widget _buildPassengerTile(int index) {
    return ListTile(leading: _buildVerificationSwitch(index), title: Text(alumnos[index]["nombre"]));
  }

  Widget _buildVerificationSwitch(int index) {
    return Switch(
      value: alumnos[index]["verificado"],
      activeColor: Colors.green,
      onChanged: (value) {
        setState(() {
          if (!alumnos[index]["verificado"] && value) {
            alumnosVerificados++;
          } else if (alumnos[index]["verificado"] && !value) {
            alumnosVerificados--;
          }
          alumnos[index]["verificado"] = value;
        });
      },
    );
  }
}

class QRViewExample extends StatefulWidget {
  @override
  _QRViewExampleState createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  StreamSubscription<Barcode>? _sub;
  bool _handled = false;

  @override
  void dispose() {
    _sub?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated));
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    _sub = controller.scannedDataStream.listen((scanData) async {
      if (_handled) return;
      _handled = true;
      try {
        await controller.pauseCamera();
      } catch (_) {}
      await _sub?.cancel();
      _sub = null;
      final raw = scanData.code ?? '';
      final idStr = extractTourPassenger(raw);
      Future.microtask(() async {
        if (!mounted) return;
        await Navigator.of(context).maybePop(idStr);
      });
    });
  }
}

String? extractTourPassenger(String raw) {
  try {
    final parsed = json.decode(raw);
    if (parsed is Map && parsed['url'] is String) {
      final uri = Uri.parse(parsed['url'] as String);
      return uri.queryParameters['tourPassenger'];
    }
  } catch (_) {}
  try {
    final uri = Uri.parse(raw);
    final qp = uri.queryParameters['tourPassenger'];
    if (qp != null) return qp;
  } catch (_) {}
  final m = RegExp(r'tourPassenger=([^&\s]+)').firstMatch(raw);
  return m?.group(1);
}
