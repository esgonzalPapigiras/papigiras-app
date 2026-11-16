import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:papigiras_app/design/special_diets_summary.dart';
import 'package:papigiras_app/design/apple_design_trial.dart';
import 'package:papigiras_app/design/coordinator_home_style.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';

/// PG-019 / PG-022 / PG-025: home presentation. Navigation and data stay in the page.
class CoordinatorHomeTrial extends StatelessWidget {
  const CoordinatorHomeTrial({
    super.key,
    required this.name,
    required this.school,
    required this.course,
    required this.season,
    required this.departure,
    required this.returnDate,
    this.tourCode = '',
    required this.avatar,
    required this.locationToggle,
    required this.passengers,
    required this.onProfile,
    required this.onMenu,
    required this.onNewHito,
    required this.actions,
  });

  final String name, school, course, season, departure, returnDate, tourCode;
  final Widget avatar, locationToggle, passengers;
  final VoidCallback onProfile, onMenu, onNewHito;
  final List<HomeTrialAction> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Column(
          children: [
            _toolbar(context),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: ColoredBox(
                  color: AppleTrialColors.surface,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          key: const PageStorageKey('coordinator-home-scroll'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: CoordinatorHomeStyle.contentInset,
                            vertical: CoordinatorHomeStyle.sectionSpacing,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _profile(context),
                                  const SizedBox(
                                    height: CoordinatorHomeStyle.sectionSpacing,
                                  ),
                                  _tripSummary(context),
                                  const SizedBox(
                                    height: CoordinatorHomeStyle.sectionSpacing,
                                  ),
                                  passengers,
                                  const SizedBox(
                                    height: CoordinatorHomeStyle.sectionSpacing,
                                  ),
                                  _actions(context),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('home-new-hito'),
                                onPressed: onNewHito,
                                icon: const Icon(CupertinoIcons.plus, size: 22),
                                label: const Text('Nuevo hito'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return SizedBox(
      key: const ValueKey('coordinator-home-toolbar'),
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/logo-letras-papigiras.png',
                  height: 40,
                  semanticLabel: 'PapiGiras',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Abrir menú',
              onPressed: onMenu,
              icon: const Icon(Icons.menu, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profile(BuildContext context) {
    final identity = Semantics(
      button: true,
      label: 'Abrir mi perfil',
      child: InkWell(
        onTap: onProfile,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: CoordinatorHomeStyle.identity(context)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Mi perfil',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: AppleTrialColors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(17) > 25) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [avatar, const Spacer(), locationToggle],
              ),
              const SizedBox(height: 8),
              identity,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: identity),
            const SizedBox(width: 4),
            locationToggle,
          ],
        );
      },
    );
  }

  String _displayDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _tripSummary(BuildContext context) {
    final suffix = [
      course,
      season,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' · ');
    final title = [
      school.trim(),
      suffix,
    ].where((s) => s.isNotEmpty).join(' · ');
    final destination = homeDestinationCode(tourCode);
    final dates = '${_displayDate(departure)} → ${_displayDate(returnDate)}';
    final dateLabel =
        'Salida: ${_displayDate(departure)}. '
        'Regreso: ${_displayDate(returnDate)}';
    final style = CoordinatorHomeStyle.tripTitle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            bool fits(String value) {
              final painter = TextPainter(
                text: TextSpan(text: value, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 2,
              )..layout(maxWidth: constraints.maxWidth);
              final fits = !painter.didExceedMaxLines;
              painter.dispose();
              return fits;
            }

            var display = title;
            final truncated = !fits(title);
            if (truncated && suffix.isNotEmpty) {
              // Reserve course/year before shortening only the school name.
              // Never shrink the user's text scale to enforce the two-line limit.
              final letters = school.trim().characters.toList();
              var low = 0, high = letters.length;
              while (low < high) {
                final middle = (low + high + 1) ~/ 2;
                final candidate =
                    '${letters.take(middle).join().trimRight()}… · $suffix';
                if (fits(candidate)) {
                  low = middle;
                } else {
                  high = middle - 1;
                }
              }
              display = '${letters.take(low).join().trimRight()}… · $suffix';
            }
            final text = Text(
              display,
              key: const ValueKey('home-trip-title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
            return Semantics(
              header: true,
              button: truncated,
              label: title,
              hint: truncated
                  ? 'Toca para leer los datos completos de la gira'
                  : null,
              child: truncated
                  ? InkWell(
                      key: const ValueKey('home-trip-full-details'),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          scrollable: true,
                          title: const Text('Datos de la gira'),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title),
                              if (destination != null) ...[
                                const SizedBox(height: 16),
                                Text('Destino: $destination'),
                              ],
                              const SizedBox(height: 16),
                              Text('Salida: ${_displayDate(departure)}'),
                              Text('Regreso: ${_displayDate(returnDate)}'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ExcludeSemantics(child: text),
                        ),
                      ),
                    )
                  : ExcludeSemantics(child: text),
            );
          },
        ),
        const SizedBox(height: 10),
        if (destination != null) ...[
          Row(
            children: [
              const Icon(
                CupertinoIcons.map_pin,
                size: 16,
                color: AppleTrialColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Destino · $destination',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        // One line at every text size. Larger accessibility text can scroll
        // horizontally, with full departure/return meaning in one semantic node.
        Semantics(
          label: dateLabel,
          excludeSemantics: true,
          child: SingleChildScrollView(
            key: const ValueKey('home-trip-dates-scroll'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.calendar,
                  size: 16,
                  color: AppleTrialColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  dates,
                  key: const ValueKey('home-trip-dates'),
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(15) > 22;
        final oneColumn = constraints.maxWidth < 300 || largeText;
        final primary = actions.take(2).toList();
        final secondary = actions.skip(2).toList();
        final children = <Widget>[];
        if (oneColumn) {
          for (final action in primary) {
            if (children.isNotEmpty) children.add(const SizedBox(height: 8));
            children.add(_action(context, action, primary: true));
          }
        } else if (primary.isNotEmpty) {
          children.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < primary.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _action(context, primary[i], primary: true),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        if (secondary.isNotEmpty) {
          if (children.isNotEmpty) children.add(const SizedBox(height: 12));
          // Keep the utility buttons in one row. With accessibility text,
          // allow horizontal scrolling instead of shrinking or clipping labels.
          final minWidth = largeText
              ? (MediaQuery.textScalerOf(context).scale(96) + 16) *
                        secondary.length +
                    8 * (secondary.length - 1)
              : constraints.maxWidth;
          children.add(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: minWidth > constraints.maxWidth
                    ? minWidth
                    : constraints.maxWidth,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < secondary.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _action(context, secondary[i], primary: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Column(children: children);
      },
    );
  }

  Widget _action(
    BuildContext context,
    HomeTrialAction action, {
    required bool primary,
  }) {
    final apple =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final icon = SizedBox.square(
      dimension: primary ? 32 : 28,
      child: Icon(
        apple ? action.appleIcon : action.materialIcon,
        size: primary ? 28 : 25,
        color: AppleTrialColors.accent,
      ),
    );
    final label = Text(
      action.label,
      textAlign: primary ? TextAlign.start : TextAlign.center,
      style: CoordinatorHomeStyle.actionLabel(context, primary: primary),
    );
    return Material(
      color: primary
          ? (action.id == 'map'
                ? const Color(0xFFE9F4F0)
                : const Color(0xFFF2F4F3))
          : CoordinatorHomeStyle.panelColor,
      borderRadius: BorderRadius.circular(CoordinatorHomeStyle.panelRadius),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          key: ValueKey('home-action-${action.id}'),
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: primary ? 88 : 84),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: primary ? 16 : 6,
                vertical: 12,
              ),
              child: primary
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [icon, const SizedBox(height: 8), label],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [icon, const SizedBox(height: 8), label],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTrialAction {
  const HomeTrialAction(
    this.id,
    this.label,
    this.appleIcon,
    this.materialIcon,
    this.onTap,
  );
  final String id, label;
  final IconData appleIcon, materialIcon;
  final VoidCallback onTap;
}

class HomeTrialPassengers extends StatelessWidget {
  const HomeTrialPassengers({
    super.key,
    required this.male,
    required this.female,
    required this.maleCompanion,
    required this.femaleCompanion,
    required this.onOpen,
    this.specialDietCounts,
    this.onOpenDiets,
  });
  final int male, female, maleCompanion, femaleCompanion;
  final VoidCallback onOpen;
  final Map<String, int>? specialDietCounts;
  final VoidCallback? onOpenDiets;

  @override
  Widget build(BuildContext context) {
    final pilo = PiloFamilyTheme.isActive(context);
    final accent = pilo ? PiloFamilyTheme.ink : AppleTrialColors.accent;
    final columns = [
      _group(context, 'Alumnos', male, female),
      _group(context, 'Acompañantes', maleCompanion, femaleCompanion),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 20;
    return Material(
      color: pilo ? PiloFamilyTheme.soft : CoordinatorHomeStyle.panelColor,
      borderRadius: BorderRadius.circular(
        pilo ? 28 : CoordinatorHomeStyle.panelRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          children: [
            largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      columns.first,
                      const SizedBox(height: 16),
                      columns.last,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: columns.first),
                      const SizedBox(width: 16),
                      Expanded(child: columns.last),
                    ],
                  ),
            const SizedBox(height: 12),
            SpecialDietsSummary(counts: specialDietCounts, onOpen: onOpenDiets),
            Divider(height: 1, color: pilo ? PiloFamilyTheme.hairline : null),
            Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('home-passenger-list'),
                onTap: onOpen,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: CoordinatorHomeStyle.leadingSize,
                          child: Icon(
                            Icons.medical_services_outlined,
                            size: 22,
                            color: pilo
                                ? PiloFamilyTheme.accentText
                                : const Color(0xFF7B4AB5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nómina y fichas médicas',
                            style: CoordinatorHomeStyle.rowLabel(
                              context,
                            ).copyWith(color: accent),
                          ),
                        ),
                        Icon(
                          pilo
                              ? Icons.arrow_forward_rounded
                              : CupertinoIcons.chevron_right,
                          size: pilo ? 20 : 16,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String label, int men, int women) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${men + women}',
                style: CoordinatorHomeStyle.statistic(context),
              ),
              TextSpan(text: '  $label'),
            ],
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Semantics(
          label:
              '$label: $men ${men == 1 ? 'hombre' : 'hombres'} y '
              '$women ${women == 1 ? 'mujer' : 'mujeres'}',
          excludeSemantics: true,
          child: Text(
            '♂ $men   ♀ $women',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// The existing backend constructs tourCode as toursName + numeric identifiers.
/// Only display an identifiable prefix, never infer a city or a program name.
String? homeDestinationCode(String tourCode) => RegExp(
  r'^([A-Z]{2,8})[0-9]{6,}[A-Z0-9]*$',
).firstMatch(tourCode.trim().toUpperCase())?.group(1);
