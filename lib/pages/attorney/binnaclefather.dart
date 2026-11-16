import '../../navigation/family_navigation.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/utils/page_navigation.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/maps/trip_binnacle_timeline.dart';
import 'package:papigiras_app/maps/trip_map_data.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/dto/ResponseImagePassenger.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/attorney/binnacledetailFather.dart';
import 'package:papigiras_app/pages/attorney/indexFather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class BitacoraFatherScreen extends StatefulWidget {
  @override
  _BitacoraFatherScreenState createState() => _BitacoraFatherScreenState();
  final ResponseAttorney login;
  final CoordinatorProviders? provider;
  BitacoraFatherScreen({super.key, required this.login, this.provider});
}

class _BitacoraFatherScreenState extends State<BitacoraFatherScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final usuarioProvider = widget.provider ?? CoordinatorProviders();
  XFile? _image;
  String? _imageUrl;

  Future<void> _loadImage() async {
    try {
      Responseimagepassenger imageUrl = await usuarioProvider
          .getPicturePassenger(
            widget.login.passengerIdentificacion.toString(),
            widget.login.tourId.toString(),
          );

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _imageUrl = null; // Si ocurre un error, usar la predeterminada
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    if (widget.provider == null) usuarioProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: _image,
        imageUrl: _imageUrl,
      ),
      body: widget.login.tourId == null || widget.login.tourId! <= 0
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(null),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No encontramos una gira asociada a este perfil.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : TripBinnacleTimeline(
              tourId: widget.login.tourId!,
              onOpenDetail: _openBinnacleDetail,
              provider: widget.provider,
              onOpenMap: FamilyNavigationScope.maybeOf(context)?.openMap,
              familyHeader: _header,
            ),
    ),
  );

  void _back() {
    final navigation = FamilyNavigationScope.maybeOf(context);
    if (navigation != null) {
      navigation.back();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        buildPapiRoute(TravelFatherDashboard(login: widget.login)),
      );
    }
  }

  Widget _header(VoidCallback? onRefresh) => PiloSectionBar(
    title: 'Bitácora',
    compact: true,
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
    onBack: _back,
    actions: [
      IconButton(
        tooltip: 'Actualizar bitácora',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      IconButton(
        tooltip: 'Abrir menú',
        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        icon: const Icon(Icons.menu_rounded),
      ),
    ],
  );

  Future<void> _openBinnacleDetail(TripMapEntry entry) async {
    await Navigator.of(context).push(
      _createRoute(
        DetalleBitacoraFatherScreen(
          idHito: entry.id.toString(),
          login: widget.login,
          provider: widget.provider,
        ),
      ),
    );
  }

  Route _createRoute(Widget destination) => buildPapiRoute(destination);
}
