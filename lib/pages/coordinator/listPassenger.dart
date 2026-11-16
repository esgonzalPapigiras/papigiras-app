import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/design/trip_display_names.dart';
import 'package:papigiras_app/design/special_diet_icon.dart';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/PassengerList.dart';
import 'package:papigiras_app/dto/TourSales.dart';
import 'package:papigiras_app/lab/media_data.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:papigiras_app/utils/coordinator_widgets.dart';
import 'package:papigiras_app/utils/passenger_roster_data.dart';

const _medicalPending = Color(0xFF805116);

class ListPassengerCoordScreen extends StatefulWidget {
  const ListPassengerCoordScreen({
    super.key,
    required this.login,
    this.provider,
    this.passengerLoader,
    this.photoLoader,
  });

  final TourSales login;
  final CoordinatorProviders? provider;

  /// Explicit injection for widget/visual QA. Production callers keep the
  /// existing protected provider; failures never fall back to sample records.
  final Future<List<PassengerList>> Function(String tourId)? passengerLoader;
  final Future<Uint8List?> Function(String rut, String tourId)? photoLoader;

  @override
  State<ListPassengerCoordScreen> createState() =>
      _ListPassengerCoordScreenState();
}

class _ListPassengerCoordScreenState extends State<ListPassengerCoordScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _query = '';
  late CoordinatorProviders _provider;
  final _photos = LinkedHashMap<String, Future<Uint8List?>>();
  final _busy = <int>{};
  List<PassengerList>? _people;
  RosterFilter _filter = RosterFilter.all;
  RosterSexFilter _sexFilter = RosterSexFilter.all;
  RosterMedicalFilter _medicalFilter = RosterMedicalFilter.all;
  bool _specialDietOnly = false;
  bool _ascending = true;
  bool _loading = false;
  String? _error;
  int _generation = 0;
  int _photoRevision = 0;
  bool? _wasCurrent;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
    WidgetsBinding.instance.addObserver(this);
    _provider = widget.provider ?? CoordinatorProviders();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (_wasCurrent == false && current) {
      _scheduleRefresh();
    }
    _wasCurrent = current;
  }

  @override
  void didUpdateWidget(covariant ListPassengerCoordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.login.tourSalesId != widget.login.tourSalesId ||
        oldWidget.provider != widget.provider ||
        oldWidget.passengerLoader != widget.passengerLoader ||
        oldWidget.photoLoader != widget.photoLoader) {
      ++_generation;
      if (oldWidget.provider == null) _provider.dispose();
      _provider = widget.provider ?? CoordinatorProviders();
      _people = null;
      _loading = false;
      _busy.clear();
      _filter = RosterFilter.all;
      _sexFilter = RosterSexFilter.all;
      _medicalFilter = RosterMedicalFilter.all;
      _specialDietOnly = false;
      _ascending = true;
      _search.clear();
      _photos.clear();
      _scheduleRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasCurrent != false) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    if (widget.provider == null) _provider.dispose();
    _scroll.dispose();
    _search.dispose();
    _photos.clear();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _photos.clear();
      ++_photoRevision;
    });
    try {
      final people =
          await (widget.passengerLoader ?? _provider.getListPassenger)(
            widget.login.tourSalesId.toString(),
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _people = people;
        if (!rosterClassificationAvailable(people)) {
          _filter = RosterFilter.all;
          _sexFilter = RosterSexFilter.all;
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(
        () =>
            _error = 'No pudimos actualizar el listado. Inténtalo nuevamente.',
      );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<Uint8List?> _photo(PassengerList person) {
    final identification = person.passengerIdentification;
    if (identification.trim().isEmpty) return Future.value();
    final key = '${widget.login.tourSalesId}:$identification';
    final cached = _photos.remove(key);
    if (cached != null) {
      _photos[key] = cached;
      return cached;
    }
    // The legacy endpoint calls this parameter passengerId, but its canonical
    // lookup is the passenger RUT. Never substitute the numeric database ID.
    final requested = Future<Uint8List?>.sync(() async {
      try {
        if (widget.photoLoader case final load?) {
          return await load(
            identification,
            widget.login.tourSalesId.toString(),
          );
        }
        final response = await _provider.getPicturePassenger(
          identification,
          widget.login.tourSalesId.toString(),
        );
        return LocalImageData.decode(response.image);
      } catch (_) {
        return null;
      }
    });
    _photos[key] = requested;
    while (_photos.length > 24) {
      _photos.remove(_photos.keys.first);
    }
    return requested;
  }

  void _searchChanged() {
    final query = _search.text;
    if (!mounted || query == _query) return;
    setState(() => _query = query);
  }

  void _chooseFilter(RosterFilter filter) {
    setState(() => _filter = _filter == filter ? RosterFilter.all : filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _chooseSexFilter(RosterSexFilter filter) {
    setState(
      () => _sexFilter = _sexFilter == filter ? RosterSexFilter.all : filter,
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _setMedicalFilter(RosterMedicalFilter filter) {
    setState(() => _medicalFilter = filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _resetFilters() {
    setState(() {
      _filter = RosterFilter.all;
      _sexFilter = RosterSexFilter.all;
      _medicalFilter = RosterMedicalFilter.all;
      _specialDietOnly = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _pendingMedical() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este pasajero aún no tiene una ficha médica guardada.'),
      ),
    );
  }

  Future<void> _medical(PassengerList person) async {
    if (_busy.contains(person.passengerId)) return;
    if (!hasSavedMedicalRecord(person)) {
      _pendingMedical();
      return;
    }
    final tour = widget.login.tourSalesId.toString();
    final provider = _provider;
    setState(() => _busy.add(person.passengerId));
    try {
      await provider.viewDocumentMedicalRecord(
        tour,
        person.passengerId.toString(),
        context,
        person.passengerIdentification,
      );
    } catch (_) {
      if (!mounted ||
          !identical(_provider, provider) ||
          widget.login.tourSalesId.toString() != tour)
        return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos abrir la ficha médica. Inténtalo nuevamente.',
          ),
        ),
      );
    } finally {
      if (mounted &&
          identical(_provider, provider) &&
          widget.login.tourSalesId.toString() == tour) {
        setState(() => _busy.remove(person.passengerId));
      }
    }
  }

  ThemeData _rosterTheme() {
    final theme = PiloFamilyTheme.theme(Theme.of(context));
    return theme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PiloFamilyTheme.accentText,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _rosterTheme(),
    child: Scaffold(
      key: _scaffoldKey,
      endDrawer: CoordinatorEndDrawer(login: widget.login),
      body: Column(
        children: [
          PiloSectionBar(
            title: 'Pasajeros',
            compact: true,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            onBack: () => backCoordinatorPage(context),
            actions: [
              IconButton(
                key: const ValueKey('roster-refresh'),
                tooltip: 'Actualizar pasajeros y fotos',
                onPressed: _loading ? null : _refresh,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Abrir menú',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
          Expanded(child: _content()),
        ],
      ),
    ),
  );

  Widget _content() {
    final people = _people;
    if (people == null) {
      return _error == null
          ? const Center(
              child: CircularProgressIndicator(
                color: PiloFamilyTheme.accentText,
              ),
            )
          : _initialError();
    }
    final counts = RosterCounts(people);
    final classified = rosterClassificationAvailable(people);
    final visible = rosterPeople(
      people,
      filter: _filter,
      sexFilter: _sexFilter,
      ascending: _ascending,
      query: _query,
      medicalFilter: _medicalFilter,
      specialDietOnly: _specialDietOnly,
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      color: PiloFamilyTheme.accentText,
      child: CustomScrollView(
        key: const PageStorageKey('passenger-roster'),
        controller: _scroll,
        cacheExtent: 0,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('roster-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(
                      fontSize: 16,
                      color: PiloFamilyTheme.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o RUT',
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF546760),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: PiloFamilyTheme.accentText,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey('roster-search-clear'),
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _search.clear,
                              icon: const Icon(
                                Icons.cancel_rounded,
                                size: 20,
                                color: PiloFamilyTheme.secondary,
                              ),
                            ),
                      filled: true,
                      fillColor: PiloFamilyTheme.soft,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: PiloFamilyTheme.accentText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      _quickFilter(
                        key: 'roster-medical-missing',
                        label: 'Sin ficha médica',
                        showCount: true,
                        count: counts.missingMedical,
                        selected: _medicalFilter == RosterMedicalFilter.missing,
                        icon: Icons.medical_information_outlined,
                        onTap: () => _setMedicalFilter(
                          _medicalFilter == RosterMedicalFilter.missing
                              ? RosterMedicalFilter.all
                              : RosterMedicalFilter.missing,
                        ),
                      ),
                      _quickFilter(
                        key: 'roster-diet-filter',
                        label: 'Dietas especiales',
                        showCount: true,
                        count: people.every((p) => p.hasDietInformation)
                            ? counts.specialDiets
                            : null,
                        selected: _specialDietOnly,
                        icon: Icons.restaurant_rounded,
                        onTap: () {
                          setState(() => _specialDietOnly = !_specialDietOnly);
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                        },
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      for (final filter in [
                        RosterFilter.students,
                        RosterFilter.companions,
                      ])
                        _quickFilter(
                          key: 'roster-filter-${filter.name}',
                          label: rosterFilterLabel(filter),
                          selected: _filter == filter,
                          onTap: classified
                              ? () => _chooseFilter(filter)
                              : null,
                        ),
                      for (final sex in [
                        RosterSexFilter.male,
                        RosterSexFilter.female,
                      ])
                        _quickFilter(
                          key: 'roster-sex-${sex.name}',
                          label: sex == RosterSexFilter.male
                              ? 'Hombres'
                              : 'Mujeres',
                          selected: _sexFilter == sex,
                          onTap: classified
                              ? () => _chooseSexFilter(sex)
                              : null,
                        ),
                    ],
                  ),
                  if (!classified)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Clasificación no disponible',
                        style: TextStyle(
                          fontSize: 13,
                          color: PiloFamilyTheme.secondary,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${visible.length} de ${people.length} pasajeros',
                        key: const ValueKey('roster-results'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: PiloFamilyTheme.secondary,
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('roster-sort'),
                        onPressed: () =>
                            setState(() => _ascending = !_ascending),
                        style: TextButton.styleFrom(
                          foregroundColor: PiloFamilyTheme.ink,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(
                          _ascending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 17,
                        ),
                        label: Text(_ascending ? 'A–Z' : 'Z–A'),
                      ),
                      if (_filter != RosterFilter.all ||
                          _sexFilter != RosterSexFilter.all ||
                          _medicalFilter != RosterMedicalFilter.all ||
                          _specialDietOnly)
                        Tooltip(
                          message: 'Restablecer filtros',
                          child: TextButton(
                            key: const ValueKey('roster-reset-filters'),
                            onPressed: _resetFilters,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: const Text(
                              'Limpiar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_specialDietOnly &&
                      people.any((p) => !p.hasDietInformation))
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Hay pasajeros sin información de dieta.',
                        style: TextStyle(
                          fontSize: 13,
                          color: PiloFamilyTheme.secondary,
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: PiloFamilyTheme.secondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                child: Column(
                  children: [
                    Text(
                      people.isEmpty
                          ? 'No hay pasajeros en esta gira.'
                          : _search.text.trim().isNotEmpty
                          ? 'No encontramos pasajeros con esa búsqueda.'
                          : 'No hay pasajeros con estos filtros.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PiloFamilyTheme.secondary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      TextButton(
                        onPressed: _search.clear,
                        child: const Text('Limpiar búsqueda'),
                      ),
                    if (_filter != RosterFilter.all ||
                        _sexFilter != RosterSexFilter.all ||
                        _medicalFilter != RosterMedicalFilter.all ||
                        _specialDietOnly)
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Quitar filtros'),
                      ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _row(visible[index]),
                childCount: visible.length,
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
          ),
        ],
      ),
    );
  }

  Widget _initialError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No pudimos cargar los pasajeros.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PiloFamilyTheme.secondary, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _quickFilter({
    required String key,
    required String label,
    int? count,
    bool showCount = false,
    required bool selected,
    IconData? icon,
    required VoidCallback? onTap,
  }) => Semantics(
    selected: selected,
    child: FilledButton.tonalIcon(
      key: ValueKey(key),
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: selected ? PiloFamilyTheme.ink : PiloFamilyTheme.soft,
        foregroundColor: selected ? PiloFamilyTheme.paper : PiloFamilyTheme.ink,
        shape: const StadiumBorder(),
      ),
      icon: icon == null ? null : Icon(icon, size: 14),
      label: Text(
        showCount ? '$label · ${count ?? '—'}' : label,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _badge(String text, {bool companion = false, IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: companion ? PiloFamilyTheme.ink : const Color(0xFFFFF2D7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: companion ? PiloFamilyTheme.paper : _medicalPending,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: companion ? PiloFamilyTheme.paper : _medicalPending,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _row(PassengerList person) {
    final saved = hasSavedMedicalRecord(person);
    final busy = _busy.contains(person.passengerId);
    final name = rosterName(person);
    final surname = person.passengerApellidos?.trim() ?? '';
    final formattedName = formatStudentName(
      name,
      surname.isNotEmpty && !name.toLowerCase().endsWith(surname.toLowerCase())
          ? surname
          : null,
    );
    final category = rosterCategory(person);
    final companion =
        category == RosterFilter.companionsMale ||
        category == RosterFilter.companionsFemale;
    return Container(
      key: ValueKey('roster-passenger-${person.passengerId}'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _avatar(person),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedName,
                  style: const TextStyle(
                    color: PiloFamilyTheme.ink,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  person.passengerIdentification,
                  style: const TextStyle(
                    color: PiloFamilyTheme.secondary,
                    fontSize: 12,
                  ),
                ),
                if (companion) ...[
                  const SizedBox(height: 7),
                  KeyedSubtree(
                    key: ValueKey('roster-companion-${person.passengerId}'),
                    child: _badge('Acompañante', companion: true),
                  ),
                ],
                if (hasSpecialDiet(person))
                  Padding(
                    key: ValueKey('roster-diet-${person.passengerId}'),
                    padding: const EdgeInsets.only(top: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SpecialDietIcon(compact: true),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Dieta: ${person.passengerDiet!.trim()}',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: _medicalPending,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: TextButton(
              key: ValueKey('roster-medical-${person.passengerId}'),
              onPressed: busy ? null : () => _medical(person),
              style: TextButton.styleFrom(
                foregroundColor: saved
                    ? PiloFamilyTheme.accentText
                    : PiloFamilyTheme.secondary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: saved
                          ? PiloFamilyTheme.mint
                          : const Color(0xFFE0E4E2),
                      shape: BoxShape.circle,
                    ),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.medical_information_outlined,
                            color: saved
                                ? PiloFamilyTheme.ink
                                : PiloFamilyTheme.secondary,
                            size: 24,
                          ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    saved ? 'Ficha médica' : 'Sin ficha médica',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(PassengerList person) => ExcludeSemantics(
    child: ClipOval(
      key: ValueKey('roster-avatar-${person.passengerId}'),
      child: SizedBox.square(
        dimension: 48,
        child: ColoredBox(
          color: PiloFamilyTheme.paper,
          child: FutureBuilder<Uint8List?>(
            key: ValueKey('roster-photo-${person.passengerId}-$_photoRevision'),
            future: _photo(person),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null)
                return const Icon(
                  Icons.person_outline,
                  color: PiloFamilyTheme.secondary,
                  size: 27,
                );
              return Image.memory(
                bytes,
                key: ValueKey('roster-image-${person.passengerId}'),
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person_outline,
                  color: PiloFamilyTheme.secondary,
                  size: 27,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
