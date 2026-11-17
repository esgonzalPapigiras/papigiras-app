import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/app_drawer_father.dart';

class ViewProgramScreen extends StatefulWidget {
  const ViewProgramScreen({super.key, required this.login});
  final ResponseAttorney login;

  @override
  State<ViewProgramScreen> createState() => _ViewProgramScreenState();
}

class _ViewProgramScreenState extends State<ViewProgramScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late Future<ProgramViewDto> _program;
  String? _drawerImage;

  @override
  void initState() {
    super.initState();
    _program = _loadProgram();
    _loadImage();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<ProgramViewDto> _loadProgram() =>
      _provider.getviewProgram(widget.login.tourId.toString());

  void _refresh() => setState(() => _program = _loadProgram());

  Future<void> _loadImage() async {
    try {
      final photo = await _provider.getPicturePassenger(
        widget.login.passengerIdentificacion.toString(),
        widget.login.tourId.toString(),
      );
      if (mounted) {
        setState(() => _drawerImage = photo.image.isEmpty ? null : photo.image);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PapigirasColors.canvas,
      endDrawer: AppDrawerFather(
        login: widget.login,
        imageFile: null,
        imageUrl: _drawerImage,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<ProgramViewDto>(
                future: _program,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final program = snapshot.data;
                  if (snapshot.hasError || program == null) {
                    return _MessageState(
                      icon: Icons.cloud_off_outlined,
                      message: 'No pudimos cargar el programa.',
                      onRetry: _refresh,
                    );
                  }
                  return _ProgramContent(program: program, login: widget.login);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('Programa',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          IconButton(
            tooltip: 'Actualizar programa',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Abrir menú',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProgramContent extends StatelessWidget {
  const _ProgramContent({required this.program, required this.login});
  final ProgramViewDto program;
  final ResponseAttorney login;

  @override
  Widget build(BuildContext context) {
    final activities = program.activities ?? const <String>[];
    final course = [
      program.nameClient,
      program.courseClient,
      program.seasonClient?.toString(),
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    final passenger = [login.passengerName, login.passengerApellidos]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PapigirasColors.soft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: PapigirasColors.mint,
                foregroundColor: PapigirasColors.onMint,
                child: Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger.isEmpty ? 'Pasajero' : passenger,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      login.passengerIdentificacion ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Curso',
          icon: Icons.school_outlined,
          children: [
            Text(course.isEmpty ? 'Sin información de curso' : course)
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Fechas de la gira',
          icon: Icons.calendar_month_outlined,
          children: [
            _DateRow(label: 'Salida', value: program.tourInit),
            const Divider(height: 24),
            _DateRow(label: 'Regreso', value: program.tourEnd),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Actividades de la gira',
          icon: Icons.route_outlined,
          children: activities.isEmpty
              ? const [Text('No hay actividades disponibles.')]
              : [
                  for (var index = 0; index < activities.length; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: PapigirasColors.mint,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: PapigirasColors.onMint,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(activities[index])),
                        ],
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PapigirasColors.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: PapigirasColors.teal),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Text(
          value?.trim().isNotEmpty == true ? value! : 'Sin fecha',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon, required this.message, required this.onRetry});
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: PapigirasColors.teal),
          const SizedBox(height: 14),
          Text(message),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
