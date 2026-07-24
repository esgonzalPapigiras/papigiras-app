import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecordScreenEditCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class MedicalCoordScreen extends StatefulWidget {
  final TourSales login;
  MedicalCoordScreen({required this.login});

  @override
  _MedicalCoordScreenState createState() => _MedicalCoordScreenState();
}

class _MedicalCoordScreenState extends State<MedicalCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = CoordinatorProviders();
  List<Map<String, dynamic>> documents = [];
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchMedicalRecords();
  }

  Future<void> _fetchMedicalRecords() async {
    final passengers = await _coordinatorProvider.getListPassenger(widget.login.tourSalesId.toString());
    setState(() {
      documents = passengers.map((passenger) {
        return {
          'name': passenger.passengerName,
          'id': passenger.passengerIdentification,
          'idPassenger': passenger.passengerId,
          'passengerApellidos': passenger.passengerApellidos,
          'countMedicalRecordOk': passenger.countMedicalRecordOk,
          'countMedicalRecordNoOk': passenger.countMedicalRecordNoOk,
          'statusMedicalRecord': passenger.statusMedicalRecord
        };
      }).toList();
    });
  }

  void _sortDocuments() {
    setState(() {
      documents.sort((a, b) {
        final idA = (a['passengerApellidos'] ?? '').toString();
        final idB = (b['passengerApellidos'] ?? '').toString();
        return _isAscending ? idA.compareTo(idB) : idB.compareTo(idA);
      });
      _isAscending = !_isAscending;
    });
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildHeader(), Expanded(child: ListView(children: _buildMedicalRecordCards()))],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Fichas Médicas', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
            GestureDetector(
              onTap: _sortDocuments,
              child: Row(
                children: [
                  Text('Ordenar por Apellido', style: TextStyle(fontSize: 8, color: Colors.teal, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.teal, size: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCounter(),
      ],
    );
  }

  Widget _buildCounter() {
    if (documents.isEmpty) {
      return Center(
        child: Text('Sin datos de fichas', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Contador de fichas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              children: [
                TextSpan(text: '${documents.first['countMedicalRecordOk']}', style: const TextStyle(color: Colors.green)),
                const TextSpan(text: ' / '),
                TextSpan(text: '${documents.first['countMedicalRecordNoOk']}', style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMedicalRecordCards() {
    return documents.map((document) => _buildMedicalRecordCard(document)).toList();
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> document) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.medical_services, color: Colors.teal, size: 40),
              title: Text(document['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(document['id'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            _buildMedicalRecordActions(document),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordActions(Map<String, dynamic> document) {
    if (document['statusMedicalRecord'] != 'Lleno') {
      return const SizedBox.shrink();
    }
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_buildEditButton(document), _buildViewButton(document), _buildDownloadButton(document), _buildShareButton(document)],
      ),
    );
  }

  Widget _buildEditButton(Map<String, dynamic> document) {
    return IconButton(
      icon: const Icon(Icons.edit, color: Colors.teal),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicalRecordScreenEditCoordinator(
              login: widget.login,
              idPassenger: document['idPassenger'].toString(),
              idDocumento: document['id'].toString(),
              nombrepassenger: document['name'].toString(),
              passengerApellidos: document['passengerApellidos'].toString(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewButton(Map<String, dynamic> document) {
    return IconButton(
      icon: const Icon(Icons.remove_red_eye, color: Colors.teal),
      onPressed: () {
        _coordinatorProvider.viewDocumentMedicalRecord(widget.login.tourSalesId.toString(), document['idPassenger'].toString(), context, document['id'].toString());
      },
    );
  }

  Widget _buildDownloadButton(Map<String, dynamic> document) {
    return IconButton(
      icon: const Icon(Icons.download, color: Colors.teal),
      onPressed: () async {
        await _coordinatorProvider.downloadDocumentMedicalRecord(widget.login.tourSalesId.toString(), document['idPassenger'].toString(), document['id'].toString());
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'Éxito',
          text: 'Documento Descargado',
          confirmBtnText: 'Continuar',
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _buildShareButton(Map<String, dynamic> document) {
    return IconButton(
      icon: const Icon(Icons.share, color: Colors.teal),
      onPressed: () {
        _coordinatorProvider.shareDocumentMedicalRecord(widget.login.tourSalesId.toString(), document['idPassenger'].toString(), document['id'].toString());
      },
    );
  }
}
