import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/activities.dart';
import 'package:papigiras_app/pages/coordinator/addHito.dart';
import 'package:papigiras_app/pages/coordinator/binnacleCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/contador.dart';
import 'package:papigiras_app/pages/coordinator/documentCoordinator.dart';
import 'package:papigiras_app/pages/coordinator/listPassenger.dart';
import 'package:papigiras_app/pages/coordinator/medicalRecord.dart';
import 'package:papigiras_app/pages/coordinator/tripulationbusCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/LocationService.dart';
import 'package:provider/provider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class TravelCoordinatorDashboard extends StatefulWidget {
  final TourSales login;
  TravelCoordinatorDashboard({required this.login});

  @override
  _TravelCoordinatorDashboardState createState() => _TravelCoordinatorDashboardState();
}

class _TravelCoordinatorDashboardState extends State<TravelCoordinatorDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final usuarioProvider = new CoordinatorProviders();
  late final Future<Map<String, int>> _passengerCountsFuture;

  @override
  void initState() {
    super.initState();
    _passengerCountsFuture = usuarioProvider.getPassengerCountsBySex(
      tourCode: widget.login.tourCode,
      tourId: widget.login.tourSalesId,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final locationService = context.read<LocationService>();
      await locationService.initializeForCoordinatorSession();
      if (!mounted || locationService.lastError == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locationService.lastError!)),
      );
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
              CoordinatorTopBar(login: widget.login, scaffoldKey: _scaffoldKey, showBackButton: false),
              Expanded(child: _buildContent()),
              buildBottomBar(),
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            _buildCoordinatorProfile(),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, int>>(
              future: _passengerCountsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 42),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No se pudieron cargar los pasajeros',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }
                final counts = snapshot.data ?? const <String, int>{};
                return _buildPassengerCounters(
                  counts['M'] ?? 0,
                  counts['F'] ?? 0,
                  counts['AM'] ?? 0,
                  counts['AF'] ?? 0,
                );
              },
            ),
            const SizedBox(height: 20),
            _buildPassengerListButton(),
            _buildDateRange(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatorProfile() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 20),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
          child: const CircleAvatar(radius: 50, backgroundImage: AssetImage('assets/profile.jpg')),
        ),
        const SizedBox(width: 30),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.login.tourTripulationNameId, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 5),
              Text('En Gira con:', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              Text(
                '${widget.login.nameClient} ${widget.login.courseClient} ${widget.login.seasonClient}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerCounters(
    int countMale,
    int countFemale,
    int countMaleCompanion,
    int countFemaleCompanion,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: _buildPassengerCounterColumn(
            title: 'Alumnos a bordo',
            maleCount: countMale,
            femaleCount: countFemale,
          ),
        ),
        Container(width: 2, height: 120, color: Colors.teal),
        Expanded(
          child: _buildPassengerCounterColumn(
            title: 'Acompañantes',
            maleCount: countMaleCompanion,
            femaleCount: countFemaleCompanion,
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerCounterColumn({
    required String title,
    required int maleCount,
    required int femaleCount,
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 20),
        _buildGenderCounter(Icons.man_2, Icons.male, maleCount),
        const SizedBox(height: 20),
        _buildGenderCounter(Icons.woman_2_sharp, Icons.female, femaleCount),
      ],
    );
  }

  Widget _buildGenderCounter(
    IconData personIcon,
    IconData genderIcon,
    int value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(personIcon, color: Colors.teal, size: 30),
        Icon(genderIcon, color: Colors.teal, size: 30),
        const SizedBox(width: 10),
        Text(value.toString(), style: const TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildPassengerListButton() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility, color: Colors.teal, size: 24),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ListPassengerCoordScreen(login: widget.login)));
              },
              child: const Text('Ver Nómina Pasajeros', style: TextStyle(fontSize: 16, color: Colors.teal, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        Container(height: 2, width: 320, color: Colors.teal, margin: const EdgeInsets.symmetric(vertical: 8)),
      ],
    );
  }

  Widget _buildDateRange() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDateItem('Fecha Salida', widget.login.tourSalesInit),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward, color: Colors.teal, size: 24),
        const SizedBox(width: 16),
        _buildDateItem('Fecha Regreso', widget.login.tourSalesFinal),
      ],
    );
  }

  Widget _buildDateItem(String title, String date) {
    return Column(
      children: [
        Row(children: [const Icon(Icons.calendar_today, color: Colors.teal, size: 20), const SizedBox(width: 4), Text(title, style: const TextStyle(color: Colors.grey))]),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(color: Colors.teal, fontSize: 16)),
      ],
    );
  }

  Widget buildInfoSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        SizedBox(height: 5),
        Center(
          child: Container(
            width: 320,
            constraints: BoxConstraints(maxHeight: 80),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.all(10),
            child: TextField(
                maxLines: 3,
                decoration: InputDecoration(border: InputBorder.none, hintText: "", hintStyle: TextStyle(color: Colors.grey[600])),
                style: TextStyle(color: Colors.grey[800])),
          ),
        ),
      ],
    );
  }

  Widget buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 35),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: 5, blurRadius: 10, offset: Offset(0, -3))]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.connect_without_contact_sharp, 'Actividades', null, ActivitiesCoordScreen(login: widget.login)),
              Transform.translate(offset: Offset(0, -30), child: buildBottomButtonHito(Icons.add_circle, 'Hito', null, HitoAddCoordScreen(login: widget.login))),
              buildBottomButton(Icons.person_add_alt_1, 'Contador', null, CountDownCoordScreen(login: widget.login)),
            ],
          ),
          SizedBox(height: 5), // Espacio entre las filas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomButton(Icons.medical_information, 'Fichas Medicas', null, MedicalCoordScreen(login: widget.login)),
              buildBottomButton(Icons.directions_bus, 'Bus & Tripulación', null, BusCrewCoorScreen(login: widget.login)),
              buildBottomButton(Icons.folder_open, 'Mis Documentos', null, DocumentCoordScreen(login: widget.login)),
              buildBottomButton(Icons.book, 'Bitácora del Viaje', null, BitacoraCoordScreen(login: widget.login)),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBottomButton(IconData icon, String label, String? badge, Widget? destination) {
    return GestureDetector(
      onTap: () {
        if (destination != null) {
          Navigator.of(context).push(_createRoute(destination));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 40, color: Colors.teal), SizedBox(height: 8), Text(label, style: TextStyle(color: Colors.teal, fontSize: 8))],
      ),
    );
  }

  Widget buildBottomButtonHito(IconData icon, String label, String? badge, Widget? destination) {
    return GestureDetector(
      onTap: () {
        if (destination != null) {
          Navigator.of(context).push(_createRoute(destination));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 70, color: Colors.teal), SizedBox(height: 8), Text(label, style: TextStyle(color: Colors.teal, fontSize: 8))],
      ),
    );
  }

  Route _createRoute(Widget destination) {
    return PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 1000),
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); // Desde abajo
        const end = Offset.zero;
        const curve = Curves.ease;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}
