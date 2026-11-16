import 'package:flutter/material.dart';
import 'package:papigiras_app/lab/map.dart';
class MapScreen extends StatelessWidget {
const MapScreen({super.key});
@override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Recorrido de prueba')), body: const Center(child: LabMap()));
}
