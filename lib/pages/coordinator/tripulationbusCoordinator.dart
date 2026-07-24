import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/tourTripulation.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class BusCrewCoorScreen extends StatefulWidget {
  final TourSales login;
  BusCrewCoorScreen({required this.login});

  @override
  _BusCrewCoorScreenState createState() => _BusCrewCoorScreenState();
}

class _BusCrewCoorScreenState extends State<BusCrewCoorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = CoordinatorProviders();
  List<TourTripulation> _tripulations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripulations();
  }

  Future<void> _loadTripulations() async {
    try {
      final tripulations = await _coordinatorProvider.getTripulation(widget.login.tourSalesId.toString());
      setState(() => _tripulations = tripulations);
    } catch (e) {
      print('Error al cargar la tripulación: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildBusInformation(), const Divider(height: 40, thickness: 1), ..._buildCrewMembers()]),
      ),
    );
  }

  Widget _buildBusInformation() {
    final bus = _tripulations.isNotEmpty ? _tripulations.first : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Bus & Tripulación', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/bus.jpg', width: 100, height: 100, fit: BoxFit.cover),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBusRow('Patente', bus?.tourTripulationBusPatent, 'Sin patente'),
                    _buildBusRow('Marca', bus?.tourTripulationBusBrand, 'Sin marca'),
                    _buildBusRow('Modelo', bus?.tourTripulationBusModel, 'Sin modelo'),
                    _buildBusRow('Año', bus?.tourTripulationBusYear?.toString(), 'Año no disponible'),
                    _buildBusRow('Empresa', bus?.tourTripulationBusEnterprise, 'Sin empresa'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusRow(String label, String? value, String defaultValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? defaultValue, style: TextStyle(color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCrewMembers() {
    return _tripulations.map((tripulation) => _buildCrewMemberCard(tripulation)).toList();
  }

  Widget _buildCrewMemberCard(TourTripulation tripulation) {
    final isCoordinator = tripulation.tourTripulationTypeId == 32;
    return _buildCrewMember(
      role: isCoordinator ? 'Coordinador' : 'Conductor',
      name: tripulation.tourTripulationNameId,
      position: 'Licencia Clase A',
      id: tripulation.tourTripulationIdentificationId,
      imagePath: isCoordinator ? 'assets/conductor_one.jpg' : 'assets/conductor_two.jpg',
    );
  }

  Widget _buildCrewMember({required String role, required String name, required String position, required String id, required String imagePath}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 20.0),
      leading: Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.fitHeight, alignment: Alignment.center)),
        ),
      ),
      title: Text(role, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
          Text(position, style: TextStyle(color: Colors.grey[600])),
          Text(id, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
      onTap: () {},
    );
  }
}
