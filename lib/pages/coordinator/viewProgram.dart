import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/ProgramViewDto.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';

class ViewProgramCoordScreen extends StatefulWidget {
  const ViewProgramCoordScreen({super.key, required this.login});
  final TourSales login;

  @override
  State<ViewProgramCoordScreen> createState() => _ViewProgramCoordScreenState();
}

class _ViewProgramCoordScreenState extends State<ViewProgramCoordScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _provider = CoordinatorProviders();
  late Future<ProgramViewDto> _program;

  @override
  void initState() {
    super.initState();
    _program = _loadProgram();
  }

  Future<ProgramViewDto> _loadProgram() =>
      _provider.getviewProgram(widget.login.tourSalesId.toString());

  void _refresh() => setState(() => _program = _loadProgram());

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PapigirasColors.canvas,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onBack: () => Navigator.of(context).maybePop(),
              onRefresh: _refresh,
              onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
            Expanded(
              child: FutureBuilder<ProgramViewDto>(
                future: _program,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _MessageState(
                      icon: Icons.cloud_off_rounded,
                      message: 'No pudimos cargar el programa.',
                      actionLabel: 'Reintentar',
                      onAction: _refresh,
                    );
                  }
                  final program = snapshot.data;
                  if (program == null) {
                    return const _MessageState(
                      icon: Icons.event_note_rounded,
                      message: 'No se encontraron datos del programa.',
                    );
                  }
                  return _ProgramContent(program: program);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.onBack, required this.onRefresh, required this.onMenu});
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          IconButton(
              tooltip: 'Volver',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 4),
          Expanded(
              child: Text('Programa',
                  style: Theme.of(context).textTheme.headlineMedium)),
          IconButton(
              tooltip: 'Actualizar programa',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Abrir menú',
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded)),
        ],
      ),
    );
  }
}

class _ProgramContent extends StatelessWidget {
  const _ProgramContent({required this.program});
  final ProgramViewDto program;

  @override
  Widget build(BuildContext context) {
    final activities = program.activities ?? const <String>[];
    final course = [
      program.nameClient,
      program.courseClient,
      program.seasonClient?.toString()
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _SectionCard(title: 'Curso', icon: Icons.school_outlined, children: [
          Text(course.isEmpty ? 'Sin información de curso' : course,
              style: Theme.of(context).textTheme.bodyLarge)
        ]),
        const SizedBox(height: 14),
        _SectionCard(
            title: 'Fechas de la gira',
            icon: Icons.calendar_month_outlined,
            children: [
              _DateRow(label: 'Salida', value: program.tourInit),
              const Divider(height: 24),
              _DateRow(label: 'Regreso', value: program.tourEnd),
            ]),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Actividades de la gira',
          icon: Icons.route_outlined,
          children: activities.isEmpty
              ? const [Text('No hay actividades disponibles.')]
              : [
                  for (var index = 0; index < activities.length; index++)
                    _ActivityRow(number: index + 1, label: activities[index])
                ],
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.number, required this.label});
  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: PapigirasColors.mint, shape: BoxShape.circle),
          child: Text('$number',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PapigirasColors.onMint, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(top: 3), child: Text(label))),
      ]),
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
    return DecoratedBox(
      decoration: BoxDecoration(
          color: PapigirasColors.soft, borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: PapigirasColors.teal),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleMedium))
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
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
    return Row(children: [
      Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      Text(value?.trim().isNotEmpty == true ? value! : 'Sin fecha',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon,
      required this.message,
      this.actionLabel,
      this.onAction});
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: PapigirasColors.teal),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!))
          ],
        ]),
      ),
    );
  }
}
