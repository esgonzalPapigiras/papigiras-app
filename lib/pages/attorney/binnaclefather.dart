import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/binnacle.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnacledetailFather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class BitacoraFatherScreen extends StatefulWidget {
  @override
  _BitacoraFatherScreenState createState() => _BitacoraFatherScreenState();
  final ResponseAttorney login;
  BitacoraFatherScreen({required this.login});
}

class _BitacoraFatherScreenState extends State<BitacoraFatherScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<ConsolidatedTourSalesDTO> itineraries = [];
  final usuarioProvider = new CoordinatorProviders();
  XFile? _image;
  String? _imageUrl;
  bool _isLoadingItineraries = true;
  String? _itineraryError;

  Future<void> _loadImage() async {
    try {
      Responseimagepassenger imageUrl =
          await usuarioProvider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );

      if (imageUrl.image.isNotEmpty) {
        setState(() {
          _imageUrl = imageUrl.image; // Si la imagen existe, la cargamos
        });
      } else {
        setState(() {
          _imageUrl = null; // Si no hay imagen, usar la predeterminada
        });
      }
    } catch (e) {
      setState(() {
        _imageUrl = null; // Si ocurre un error, usar la predeterminada
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
    // Llama a fetchDocuments al iniciar el widget
    _fetchItineraries(widget.login.tourId.toString());
  }

  Future<void> _fetchItineraries(String tourCode) async {
    setState(() {
      _isLoadingItineraries = true;
      _itineraryError = null;
    });
    try {
      final data = await usuarioProvider.getBinnacle(tourCode);
      if (!mounted) return;
      setState(() {
        itineraries = data;
        _isLoadingItineraries = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingItineraries = false;
        _itineraryError = 'No se pudo cargar la bitácora.';
      });
    }
  }

  void sendMessage({required String phone, required String message}) async {
    final whatsappUrl =
        Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      print('No se puede abrir WhatsApp');
      // Intenta con el esquema directo
      final whatsappDirect = Uri.parse(
          "whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(whatsappDirect)) {
        await launchUrl(
          whatsappDirect,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'WhatsApp no está instalado o no puede manejar la URL';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF3AC5C9), // Fondo turquesa
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: _image, // remove if the screen has no image picker
        imageUrl: _imageUrl, // remove if the screen has no image URL
      ),
      body: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: _buildBinnacleContent(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar el estado de la sesión

    // Redirigir al login o realizar otra acción
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
      (route) =>
          false, // Esto elimina todas las rutas anteriores de la pila de navegación
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Colors.white, size: 30), // Flecha blanca
              onPressed: () {
                // Navegar a otra ruta cuando la flecha es presionada
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TravelFatherDashboard(
                          login:
                              widget.login)), // Reemplaza con la ruta deseada
                );
              },
            ),
          ),
          Spacer(),
          Image.asset(
            'assets/logo-letras-papigiras.png',
            height: 50,
          ),
          Spacer(),
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinnacleContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //_buildFilterOptions(),
          //SizedBox(height: 20),
          Expanded(
            child: _isLoadingItineraries
                ? const Center(child: CircularProgressIndicator())
                : _itineraryError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_itineraryError!),
                            TextButton(
                              onPressed: () => _fetchItineraries(
                                  widget.login.tourId.toString()),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : itineraries.isEmpty
                        ? const Center(
                            child: Text('Aún no hay hitos en la bitácora'))
                        : ListView(
                            children: _buildBinnacleEntries(),
                          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBinnacleEntries() {
    return itineraries.map((binnacle) {
      // Format date to show only day/month (e.g. "25/10")
      String formattedDate = binnacle.binnacleFecha;
      if (formattedDate.contains('/')) {
        List<String> parts = formattedDate.split('/');
        if (parts.length == 3) {
          formattedDate = "${parts[0]}/${parts[1]}";
        }
      }
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and time at the top
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  '$formattedDate • ${binnacle.binnacleHora}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.teal,
                  ),
                ),
              ),

              // Title (larger)
              Text(
                binnacle.binnacleTitulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              // Location (smaller, muted)
              Text(
                binnacle.binnacleUbicacion,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 10),

              // Button at the bottom-right
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(_createRoute(
                      DetalleBitacoraFatherScreen(
                        idHito: binnacle.binnacleDetailId.toString(),
                        login: widget.login,
                      ),
                    ));
                  },
                  child: const Text(
                    'Ver más',
                    style: TextStyle(color: Colors.teal),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Route _createRoute(Widget destination) {
    return PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 1000),
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); // Desde abajo
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
