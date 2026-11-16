import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/voice/trip_voice_player.dart';
import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/maps/trip_hito_content.dart';
import 'package:papigiras_app/pages/attorney/binnaclefather.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class DetalleBitacoraFatherScreen extends StatefulWidget {
  const DetalleBitacoraFatherScreen({
    super.key,
    required this.idHito,
    required this.login,
    this.provider,
  });
  final ResponseAttorney login;
  final String idHito;
  final CoordinatorProviders? provider;
  @override
  State<DetalleBitacoraFatherScreen> createState() =>
      _DetalleBitacoraFatherScreenState();
}

class _DetalleBitacoraFatherScreenState
    extends State<DetalleBitacoraFatherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final CoordinatorProviders _provider;
  late Future<DetailHitoList> _detail;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? CoordinatorProviders();
    _detail = _load();
    _loadProfile();
  }

  Future<DetailHitoList> _load() {
    final request = _provider.getHitoComplete(
      widget.idHito,
      widget.login.tourId.toString(),
    );
    // A retry may fail before the next frame attaches FutureBuilder. Register
    // an error listener now; the original future still exposes its error to UI.
    request.ignore();
    return request;
  }

  void _reload() {
    setState(() {
      _detail = _load();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final photo = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted)
        setState(() => _imageUrl = photo.image.isEmpty ? null : photo.image);
    } catch (_) {
      /* Profile photo does not block access to the hito. */
    }
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BitacoraFatherScreen(login: widget.login),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: PiloFamilyTheme.paper,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: null,
        imageUrl: _imageUrl,
      ),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Align(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Volver a la bitácora',
                        onPressed: _back,
                        style: IconButton.styleFrom(
                          backgroundColor: PiloFamilyTheme.soft,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        tooltip: 'Abrir menú',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<DetailHitoList>(
              future: _detail,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: PiloFamilyTheme.accentText,
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No pudimos cargar este hito.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: PiloFamilyTheme.secondary),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final detail = snapshot.data!;
                final note = detail.voiceNote;
                final tourId = widget.login.tourId;
                return TripHitoContent(
                  tourId: tourId,
                  hitoId: int.tryParse(widget.idHito),
                  detail: detail,
                  familyStyle: true,
                  voicePlayer: note == null || tourId == null
                      ? null
                      : TripVoicePlayer(
                          key: ValueKey('voice-${widget.idHito}-${note.id}'),
                          duration: note.duration,
                          loadFile: () => _provider.readHitoVoice(
                            int.parse(widget.idHito),
                            tourId,
                            note,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
