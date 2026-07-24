import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/pages/coordinator/detailbinnacleCoodinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class BitacoraCoordScreen extends StatefulWidget {
  final TourSales login;
  BitacoraCoordScreen({required this.login});

  @override
  _BitacoraCoordScreenState createState() => _BitacoraCoordScreenState();
}

class _BitacoraCoordScreenState extends State<BitacoraCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = CoordinatorProviders();
  List<ConsolidatedTourSalesDTO> _itineraries = [];

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  Future<void> _fetchItineraries() async {
    try {
      final itineraries = await _coordinatorProvider.getBinnacle(widget.login.tourSalesId.toString());
      setState(() => _itineraries = itineraries);
      //print("Itinerarios cargados: $itineraries");
    } catch (error) {
      print("Error al cargar los itinerarios: $error");
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ListView(children: _buildBinnacleEntries())),
        ],
      ),
    );
  }

  List<Widget> _buildBinnacleEntries() {
    return _itineraries.map((binnacle) => _buildBinnacleCard(binnacle)).toList();
  }

  Widget _buildBinnacleCard(ConsolidatedTourSalesDTO binnacle) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBinnacleDate(binnacle),
            Text(binnacle.binnacleTitulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(binnacle.binnacleUbicacion, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 10),
            _buildViewMoreButton(binnacle),
          ],
        ),
      ),
    );
  }

  Widget _buildBinnacleDate(ConsolidatedTourSalesDTO binnacle) {
    final shortDate = binnacle.binnacleFecha.split('/').sublist(0, 2).join('/');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text('$shortDate • ${binnacle.binnacleHora}', style: const TextStyle(fontSize: 11, color: Colors.teal)),
    );
  }

  Widget _buildViewMoreButton(ConsolidatedTourSalesDTO binnacle) {
    return Align(
      alignment: Alignment.bottomRight,
      child: TextButton(
        onPressed: () => _openBinnacleDetail(binnacle),
        child: const Text('Ver más', style: TextStyle(color: Colors.teal)),
      ),
    );
  }

  void _openBinnacleDetail(ConsolidatedTourSalesDTO binnacle) {
    Navigator.of(context).push(
      buildCoordinatorRoute(
        DetalleBitacoraCoordScreen(
          idHito: binnacle.binnacleDetailId.toString(),
          login: widget.login,
        ),
      ),
    );
  }
}
