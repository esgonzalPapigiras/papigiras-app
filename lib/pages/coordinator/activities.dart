import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/Itinerary.dart';
import 'package:papigiras_app/dto/RequestActivities.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/binnacleaddlist.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:quickalert/quickalert.dart';

class ActivitiesCoordScreen extends StatefulWidget {
  final TourSales login;
  const ActivitiesCoordScreen({super.key, required this.login});

  @override
  State<ActivitiesCoordScreen> createState() => _ActivitiesCoordScreenState();
}

class _ActivitiesCoordScreenState extends State<ActivitiesCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController participantsController = TextEditingController();
  final _coordinatorProvider = CoordinatorProviders();
  Itinerary? selectedActivity;
  List<Itinerary> itineraries = [];
  List<ActivitiesList> activitiesList = [];

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  @override
  void dispose() {
    participantsController.dispose();
    super.dispose();
  }

  Future<void> _fetchItineraries() async {
    try {
      final itineraries = await _coordinatorProvider.getItineray(widget.login.tourSalesId.toString());
      final activities = await _coordinatorProvider.getItinerayGuardados(widget.login.tourSalesId.toString());
      setState(() {
        this.itineraries = itineraries.toSet().toList();
        activitiesList = activities;
        if (this.itineraries.isNotEmpty) {
          selectedActivity ??= this.itineraries.first;
        }
      });
    } catch (error) {
      print("Error al cargar los itinerarios: $error");
    }
  }

  Future<void> _addActivity() async {
    if (selectedActivity == null || participantsController.text.isEmpty) {
      return;
    }
    final quantity = int.tryParse(participantsController.text);
    if (quantity == null) {
      return;
    }
    final request = RequestActivities(activityId: selectedActivity!.itineraryId, quantityPassenger: quantity, tourSalesId: widget.login.tourSalesId);
    await _coordinatorProvider.activitiesCreate(request);
    await _fetchItineraries();
    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: 'Éxito',
      text: 'Agregado con éxito',
      confirmBtnText: 'Continuar',
      onConfirmBtnTap: () {
        Navigator.of(context).pop();
        Navigator.push(context, buildCoordinatorRoute(TravelCoordinatorDashboard(login: widget.login)));
      },
    );
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
          Column(children: [
            CoordinatorTopBar(login: widget.login, scaffoldKey: _scaffoldKey),
            Expanded(child: _buildContent()),
          ]),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/background.png'), fit: BoxFit.cover)));
  }

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTitle(),
          const SizedBox(height: 20),
          _buildActivitySelector(),
          const SizedBox(height: 20),
          _buildParticipantsInput(),
          const SizedBox(height: 30),
          Expanded(child: ListView(children: _buildActivityList())),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text('Actividades', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildActivitySelector() {
    return DropdownButtonFormField<Itinerary>(
      value: selectedActivity,
      items: itineraries.map((activity) {
        return DropdownMenuItem<Itinerary>(value: activity, child: Text(activity.itinerary));
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedActivity = value;
        });
      },
      decoration: InputDecoration(
        labelText: 'Selecciona Actividad',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildParticipantsInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: participantsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Participantes',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _addActivity,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Agregar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  List<Widget> _buildActivityList() {
    return activitiesList.map((entry) => _buildActivityCard(entry)).toList();
  }

  Widget _buildActivityCard(ActivitiesList entry) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(entry.activitiesName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Container(margin: const EdgeInsets.symmetric(horizontal: 8), height: 20, width: 2, color: Colors.teal),
              Text(entry.quantityPassengerCheck.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
