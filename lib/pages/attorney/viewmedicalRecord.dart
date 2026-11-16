import 'package:flutter/material.dart';
import 'package:papigiras_app/design/medical_form_components.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/dto/PassengersMedicalRecordDTO.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/api_http.dart';
import 'package:papigiras_app/pages/attorney/fatherMedicalFile.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

/// PG-036: the saved record uses the exact same form as first entry.
class ViewMedicalRecordScreen extends StatefulWidget {
  const ViewMedicalRecordScreen({super.key, required this.login, this.provider})
    : _inSheet = false;

  const ViewMedicalRecordScreen._sheet({required this.login})
    : provider = null,
      _inSheet = true;

  final ResponseAttorney login;
  final bool _inSheet;
  @visibleForTesting
  final CoordinatorProviders? provider;

  static Future<void> showSheet(
    BuildContext context, {
    required ResponseAttorney login,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    // The built-in drag directly pops the route, bypassing PopScope. Route
    // the header swipe through maybePop so edits and saves stay protected.
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: PiloFamilyTheme.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PiloFamilyTheme.cardRadius),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return LayoutBuilder(
        builder: (context, constraints) {
          final available = (constraints.maxHeight - keyboard).clamp(
            0.0,
            constraints.maxHeight,
          );
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: SizedBox(
                height: (constraints.maxHeight * .82).clamp(0.0, available),
                child: ViewMedicalRecordScreen._sheet(login: login),
              ),
            ),
          );
        },
      );
    },
  );

  @override
  State<ViewMedicalRecordScreen> createState() =>
      _ViewMedicalRecordScreenState();
}

class _ViewMedicalRecordScreenState extends State<ViewMedicalRecordScreen> {
  late final _provider = widget.provider ?? CoordinatorProviders();
  late Future<PassengersMedicalRecordDTO> _record;
  double _dragStartY = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _record = _provider.getMedicalRecord(
      widget.login.tourId.toString(),
      widget.login.passengerId.toString(),
    );
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<PassengersMedicalRecordDTO>(
      future: _record,
      builder: (context, snapshot) {
        final missing =
            snapshot.error is LabApiException &&
            (snapshot.error as LabApiException).statusCode == 404;
        if (snapshot.hasData || missing) {
          return MedicalRecordScreen(
            login: widget.login,
            savedRecord: snapshot.data,
            provider: _provider,
            inSheet: widget._inSheet,
          );
        }
        return MedicalFormScope(
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                if (!widget._inSheet)
                  SliverToBoxAdapter(
                    child: PiloSectionBar(
                      title: 'Ficha médica',
                      onBack: () => Navigator.maybePop(context),
                    ),
                  ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: snapshot.hasError
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No se pudo cargar la ficha médica.',
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => setState(_load),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(
                              semanticsLabel: 'Cargando ficha médica',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!widget._inSheet) return content;

    return Column(
      children: [
        GestureDetector(
          key: const ValueKey('medical-sheet-header'),
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) =>
              _dragStartY = details.globalPosition.dy,
          onVerticalDragEnd: (details) {
            if (details.globalPosition.dy - _dragStartY >= 48 ||
                (details.primaryVelocity ?? 0) >= 400) {
              Navigator.maybePop(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 16, 6),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PiloFamilyTheme.connectorPast,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Ficha médica',
                          style: PiloFamilyTheme.display(32),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar ficha médica',
                      style: IconButton.styleFrom(
                        backgroundColor: PiloFamilyTheme.soft,
                        foregroundColor: PiloFamilyTheme.ink,
                        minimumSize: const Size.square(48),
                      ),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}
