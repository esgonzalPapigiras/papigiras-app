import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/dto/document.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class DocumentCoordScreen extends StatefulWidget {
  final TourSales login;
  DocumentCoordScreen({required this.login});

  @override
  _DocumentCoordScreenState createState() => _DocumentCoordScreenState();
}

class _DocumentCoordScreenState extends State<DocumentCoordScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _coordinatorProvider = new CoordinatorProviders();
  List<Document> _documents = [];

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    try {
      final documents = await _coordinatorProvider.getDocument(widget.login.tourSalesId.toString());
      setState(() => _documents = documents);
      //print("Documentos cargados: $documents");
    } catch (error) {
      print("Error al cargar los documentos: $error");
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
          _buildTitle(),
          const SizedBox(height: 20),
          Expanded(child: ListView(children: _buildDocumentCards())),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Center(
      child: Text('Mis Documentos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
    );
  }

  List<Widget> _buildDocumentCards() {
    if (_documents.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: Text("No documents found.")),
        ),
      ];
    }
    return _documents.map((document) => _buildDocumentCard(document)).toList();
  }

  Widget _buildDocumentCard(Document document) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: ListTile(
        leading: Icon(_getIconForDocumentType(document.documentType), color: Colors.teal, size: 40),
        title: Text(document.documentType ?? 'Sin nombre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        trailing: _buildActions(document),
      ),
    );
  }

  Widget _buildActions(Document document) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_red_eye, color: Colors.teal),
          onPressed: () => _viewDocument(document),
        ),
        IconButton(
          icon: const Icon(Icons.download, color: Colors.teal),
          onPressed: () => _downloadDocument(document),
        ),
      ],
    );
  }

  void _viewDocument(Document document) {
    _coordinatorProvider.viewDocument(document.tourSalesUuid, document.documentName!, widget.login.tourSalesId.toString(), context, "documentosextras");
  }

  Future<void> _downloadDocument(Document document) async {
    await _coordinatorProvider.downloadDocument(document.tourSalesUuid, document.documentName!, widget.login.tourSalesId.toString(), "documentosextras");
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
  }

  IconData _getIconForDocumentType(String documentType) {
    switch (documentType) {
      case 'poliza':
        return Icons.policy;
      case 'gira':
        return Icons.description;
      case 'hotel':
        return Icons.hotel;
      case 'Programa gira':
        return Icons.description;
      case 'Nomina alumnos':
        return Icons.people;
      default:
        return Icons.description;
    }
  }
}
