import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/pages/coordinator/indexCoordinator.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

class ViewProgramCoordScreen extends StatefulWidget {
  const ViewProgramCoordScreen({super.key, required this.login});

  final TourSales login;

  @override
  State<ViewProgramCoordScreen> createState() => _ViewProgramCoordScreenState();
}

class _ViewProgramCoordScreenState extends State<ViewProgramCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late final Future<ProgramViewDto> _program;

  @override
  void initState() {
    super.initState();
    _program = _provider.getviewProgram(widget.login.tourSalesId.toString());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    } else {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => TravelCoordinatorDashboard(login: widget.login),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        backgroundColor: PiloFamilyTheme.paper,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  tooltip: 'Cerrar menú',
                  onPressed: () => _scaffoldKey.currentState?.closeEndDrawer(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: CircleAvatar(
                  radius: 35,
                  backgroundImage: AssetImage('assets/profile.jpg'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<ProgramViewDto>(
          future: _program,
          builder: (context, snapshot) {
            final program = snapshot.data;
            final text = Theme.of(context).textTheme;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                PiloSectionBar(
                  title: 'Programa',
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  onBack: _back,
                  actions: [
                    IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: () =>
                          _scaffoldKey.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (program == null)
                  Text(
                    snapshot.hasError
                        ? 'No pudimos cargar el programa.'
                        : 'No se encontraron datos',
                    style: text.bodyMedium,
                  )
                else ...[
                  _section(context, 'Curso', [
                    Text(
                      [
                        formatSchoolName(program.nameClient),
                        program.courseClient,
                        program.seasonClient.toString(),
                      ].where((part) => part.trim().isNotEmpty).join(' · '),
                      style: text.bodyLarge,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section(context, 'Fechas de la gira', [
                    _date(context, 'Salida', program.tourInit),
                    const Divider(height: 24),
                    _date(context, 'Regreso', program.tourEnd),
                  ]),
                  const SizedBox(height: 14),
                  _section(context, 'Actividades de la gira', [
                    if (program.activities.isEmpty)
                      const Text('No hay actividades disponibles.')
                    else
                      for (final activity in program.activities)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(activity, style: text.bodyMedium),
                        ),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _date(BuildContext context, String label, String date) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        Text(date, style: text.bodyMedium),
      ],
    );
  }
}
