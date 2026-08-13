import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class ListPassengerCoordScreen extends StatefulWidget {
  @override
  _ListPassengerCoordScreenState createState() => _ListPassengerCoordScreenState();
  final TourSales login;
  ListPassengerCoordScreen({required this.login});
}

class _ListPassengerCoordScreenState extends State<ListPassengerCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isAscending = true;
  List<PassengerList> pasajeros = [];
  final usuarioProvider = CoordinatorProviders();
  List<Map<String, dynamic>> documents = [];

  @override
  void initState() {
    super.initState();
    _fetchItineraries(widget.login.tourSalesId.toString());
  }

  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDateString = prefs.getString('expiryDate');
    if (expiryDateString == null) return false;
    final expiryDate = DateTime.parse(expiryDateString);
    return DateTime.now().isBefore(expiryDate);
  }

  Future<void> _fetchItineraries(String tourCode) async {
    pasajeros = await usuarioProvider.getListPassenger(tourCode);
    setState(() {
      documents = pasajeros.map((passenger) {
        return {'name': passenger.passengerName, 'id': passenger.passengerIdentification};
      }).toList();
    });
  }

  void _sortDocuments() {
    setState(() {
      documents.sort((a, b) => _isAscending ? a['name'].compareTo(b['name']) : b['name'].compareTo(a['name']));
      _isAscending = !_isAscending;
    });
  }

  Widget _buildFilterOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text('Listado Alumnos', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        ),
        GestureDetector(
          onTap: _sortDocuments,
          child: Row(
            children: [
              Text('De la A a la Z', style: TextStyle(fontSize: 8, color: Colors.teal, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.teal, size: 10),
              SizedBox(width: 2),
              Icon(_isAscending ? Icons.arrow_downward : Icons.arrow_downward, color: Colors.teal, size: 10),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9),
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              CoordinatorTopBar(login: widget.login, scaffoldKey: _scaffoldKey),
              Expanded(child: _buildBinnacleContent()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)));
  }

  Widget _buildBinnacleContent() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildFilterOptions(), SizedBox(height: 20), Expanded(child: ListView(children: _buildBinnacleEntries()))],
      ),
    );
  }

  List<Widget> _buildBinnacleEntries() {
    return documents.map((document) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: ListTile(
          leading: Icon(Icons.person, color: Colors.teal, size: 40),
          title: Text(document['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          subtitle: Text(document['id']),
          trailing: Row(mainAxisSize: MainAxisSize.min),
        ),
      );
    }).toList();
  }  
}
