import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../design/pilo_family_theme.dart';
import '../design/trip_display_names.dart';
import '../lab/api_http.dart';
import '../lab/session.dart';
import 'coordinator_ranking_repository.dart';

/// Season leaderboard. All counts, positions and permissions come from the
/// repository; presentation never combines activity from different trips.
class CoordinatorRankingScreen extends StatefulWidget {
  const CoordinatorRankingScreen({
    super.key,
    this.initialSeason,
    this.repository,
    required this.currentCoordinatorId,
  });
  final int? initialSeason;
  final CoordinatorRankingRepository? repository;
  final int currentCoordinatorId;

  @override
  State<CoordinatorRankingScreen> createState() => _CoordinatorRankingState();
}

class _CoordinatorRankingState extends State<CoordinatorRankingScreen> {
  late final CoordinatorRankingRepository _repository;
  late final int _session;
  late int _season;
  CoordinatorRankingPage? _page;
  bool _loading = true, _loadingMore = false;
  bool _rankingChanged = false;
  bool _refreshPictures = false;
  String? _error, _moreError;
  int _request = 0;
  final _availableSeasons = <int>{};
  final _pictures = <String, Future<Uint8List?>>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpCoordinatorRankingRepository();
    _session = LabSession.generation;
    _season = widget.initialSeason ?? DateTime.now().year;
    LabSession.changed.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    LabSession.changed.removeListener(_sessionChanged);
    ++_request;
    _pictures.clear();
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted || _session == LabSession.generation) return;
    ++_request;
    _pictures.clear();
    setState(() {
      _page = null;
      _loading = false;
      _loadingMore = false;
      _error = 'Tu sesión cambió. Vuelve a abrir el ranking.';
    });
  }

  Future<void> _load({int? season}) async {
    if (_session != LabSession.generation) return;
    final request = ++_request;
    setState(() {
      _refreshPictures = _page != null;
      _pictures.clear();
      if (season != null && season != _season) {
        _season = season;
        _page = null;
        _pictures.clear();
      }
      _loading = true;
      _loadingMore = false;
      _error = null;
      _moreError = null;
      _rankingChanged = false;
    });
    try {
      final page = await _repository.load(season: _season);
      if (!mounted || request != _request || _session != LabSession.generation)
        return;
      setState(() {
        _page = page;
        _season = page.season;
        _availableSeasons.addAll(page.availableSeasons);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request || _session != LabSession.generation)
        return;
      setState(() {
        _loading = false;
        _error = error is LabApiException && error.statusCode == 403
            ? 'Vuelve a iniciar sesión como coordinador para ver el ranking.'
            : 'No pudimos actualizar el ranking. Inténtalo otra vez.';
      });
    }
  }

  Future<void> _loadMore() async {
    final page = _page;
    if (page == null ||
        !page.hasMore ||
        _loading ||
        _loadingMore ||
        _session != LabSession.generation)
      return;
    final request = _request;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final next = await _repository.load(
        season: _season,
        limit: page.limit,
        offset: page.nextOffset,
      );
      if (!mounted || request != _request || _session != LabSession.generation)
        return;
      setState(() {
        _page = page.mergeNext(next);
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _request || _session != LabSession.generation)
        return;
      setState(() {
        _loadingMore = false;
        _rankingChanged = error is FormatException;
        _moreError = _rankingChanged
            ? 'El ranking cambió. Actualiza para ver las nuevas posiciones.'
            : error is LabApiException && error.statusCode == 403
            ? 'Vuelve a iniciar sesión como coordinador para ver el ranking.'
            : 'No pudimos cargar más coordinadores.';
      });
    }
  }

  Future<Uint8List?> _picture(CoordinatorRankingEntry entry) {
    if (!entry.photoAvailable) return Future.value();
    final key = '$_season:${entry.coordinatorId}';
    return _pictures.putIfAbsent(
      key,
      () => _repository
          .loadPicture(
            season: _season,
            coordinatorId: entry.coordinatorId,
            refresh: _refreshPictures,
          )
          .catchError((Object _) => null),
    );
  }

  String _name(CoordinatorRankingEntry entry) =>
      formatStudentName(entry.firstName, entry.lastName, short: true);

  Widget _avatar(CoordinatorRankingEntry entry, {double size = 44}) =>
      _RankingAvatar(
        key: ValueKey('ranking-avatar-$_season-${entry.coordinatorId}-$size'),
        name: _name(entry),
        picture: _picture(entry),
        size: size,
      );

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final seasons = {..._availableSeasons, _season}.toList()
      ..sort((a, b) => b.compareTo(a));
    return Theme(
      data: PiloFamilyTheme.theme(Theme.of(context)),
      child: Scaffold(
        key: const ValueKey('coordinator-ranking-screen'),
        backgroundColor: PiloFamilyTheme.paper,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: RefreshIndicator(
                color: PiloFamilyTheme.accentText,
                onRefresh: _load,
                child: CustomScrollView(
                  key: const ValueKey('ranking-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  key: const ValueKey('ranking-back'),
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  tooltip: 'Volver',
                                  style: IconButton.styleFrom(
                                    backgroundColor: PiloFamilyTheme.soft,
                                  ),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const Spacer(),
                                IconButton(
                                  key: const ValueKey('ranking-refresh'),
                                  tooltip: 'Actualizar ranking',
                                  onPressed: _loading ? null : () => _load(),
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Semantics(
                              header: true,
                              child: Text(
                                'Ranking',
                                style: PiloFamilyTheme.display(
                                  MediaQuery.textScalerOf(context).scale(42) >
                                          64
                                      ? 34
                                      : 42,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Cada recuerdo cuenta.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                color: PiloFamilyTheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _seasonSelector(seasons),
                                TextButton.icon(
                                  key: const ValueKey('ranking-rules'),
                                  onPressed: () =>
                                      _showRules(context, page?.rule),
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Cómo se calcula'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: PiloFamilyTheme.accentText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_loading && page != null)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: PiloFamilyTheme.mint,
                          backgroundColor: PiloFamilyTheme.soft,
                        ),
                      ),
                    if (_error != null)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _StateCard(
                            key: const ValueKey('ranking-error'),
                            icon: Icons.cloud_off_rounded,
                            title: page == null
                                ? 'Ranking no disponible'
                                : 'No se pudo actualizar',
                            description: _error!,
                            action: _session == LabSession.generation
                                ? 'Reintentar'
                                : null,
                            onAction: () => _load(),
                          ),
                        ),
                      ),
                    if (_loading && page == null)
                      const SliverPadding(
                        padding: EdgeInsets.all(20),
                        sliver: SliverToBoxAdapter(child: _LoadingRanking()),
                      ),
                    if (page != null) ...[
                      if (page.unattributedHitoCount > 0)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                          sliver: SliverToBoxAdapter(
                            child: _PartialRankingNotice(),
                          ),
                        ),
                      if (page.entries.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: _podium(page.entries.take(3).toList()),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                        sliver: SliverToBoxAdapter(child: _myPosition(page)),
                      ),
                      if (page.entries.isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: _StateCard(
                              key: ValueKey('ranking-empty'),
                              icon: Icons.auto_awesome_outlined,
                              title: 'Aún no hay posiciones',
                              description:
                                  'Aquí aparecerán los coordinadores con publicaciones identificadas en esta temporada.',
                            ),
                          ),
                        ),
                      if (page.entries.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          sliver: SliverToBoxAdapter(
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Clasificación',
                                  style: PiloFamilyTheme.display(27),
                                ),
                                Text(
                                  '${page.totalParticipants} coordinadores',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: PiloFamilyTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.builder(
                            itemCount: page.entries.length,
                            itemBuilder: (context, index) {
                              final entry = page.entries[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RankingRow(
                                  key: ValueKey(
                                    'ranking-row-${entry.coordinatorId}',
                                  ),
                                  entry: entry,
                                  name: _name(entry),
                                  avatar: _avatar(entry),
                                  isMe:
                                      entry.coordinatorId ==
                                      page.currentCoordinatorId,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (_moreError != null)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              _moreError!,
                              style: const TextStyle(
                                color: PiloFamilyTheme.secondary,
                              ),
                            ),
                          ),
                        ),
                      if (page.hasMore)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: FilledButton.tonal(
                              key: const ValueKey('ranking-more'),
                              onPressed: _loadingMore || _loading
                                  ? null
                                  : _rankingChanged
                                  ? () => _load()
                                  : _loadMore,
                              child: Text(
                                _loadingMore
                                    ? 'Cargando…'
                                    : _rankingChanged
                                    ? 'Actualizar'
                                    : 'Ver más coordinadores',
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seasonSelector(List<int> seasons) => PopupMenuButton<int>(
    key: const ValueKey('ranking-season'),
    tooltip: 'Elegir temporada',
    initialValue: _season,
    onSelected: (value) {
      if (value != _season) _load(season: value);
    },
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    itemBuilder: (_) => [
      for (final year in seasons)
        PopupMenuItem(value: year, child: Text('Temporada $year')),
    ],
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_season',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ],
      ),
    ),
  );

  Widget _podium(List<CoordinatorRankingEntry> entries) => LayoutBuilder(
    builder: (context, constraints) {
      final accessible =
          MediaQuery.textScalerOf(context).scale(14) > 19 ||
          constraints.maxWidth < 290;
      if (accessible)
        return Column(
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RankingRow(
                  entry: entry,
                  name: _name(entry),
                  avatar: _avatar(entry, size: 48),
                  isMe: false,
                  podium: true,
                ),
              ),
          ],
        );
      final ordered = entries.length == 3
          ? [entries[1], entries[0], entries[2]]
          : entries;
      return Container(
        key: const ValueKey('ranking-podium'),
        padding: const EdgeInsets.fromLTRB(12, 22, 12, 18),
        decoration: BoxDecoration(
          color: PiloFamilyTheme.soft,
          borderRadius: BorderRadius.circular(36),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in ordered)
              Expanded(
                child: Semantics(
                  label:
                      '${_name(entry)}, puesto ${entry.rank}, ${entry.score} puntos',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (entry.rank == 1)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Icon(
                                Icons.workspace_premium_outlined,
                                size: 24,
                                color: Color(0xFF8D6418),
                              ),
                            ),
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _avatar(
                                  entry,
                                  size: entry.rank == 1 ? 72 : 60,
                                ),
                              ),
                              _medal(entry.rank),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _name(entry),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${entry.score}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: PiloFamilyTheme.ink,
                              letterSpacing: -.5,
                            ),
                          ),
                          const Text(
                            'puntos',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: PiloFamilyTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _myPosition(CoordinatorRankingPage page) {
    final me = page.myEntry;
    if (me == null)
      return Container(
        key: const ValueKey('ranking-my-empty'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE4F5F0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu próximo hito cuenta',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Publica recuerdos de tu gira para aparecer en esta temporada.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.35,
                color: PiloFamilyTheme.secondary,
              ),
            ),
          ],
        ),
      );
    return Container(
      key: const ValueKey('ranking-my-position'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.ink,
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = MediaQuery.textScalerOf(context).scale(16) > 23;
          final position = Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: PiloFamilyTheme.mint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '#${me.rank}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: PiloFamilyTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu puesto',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: PiloFamilyTheme.onDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _name(me),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final score = Text(
            '${me.score} pts',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: PiloFamilyTheme.mint,
            ),
          );
          return Semantics(
            label: 'Tu puesto ${me.rank}, ${_name(me)}, ${me.score} puntos',
            child: ExcludeSemantics(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [position, const SizedBox(height: 12), score],
                    )
                  : Row(
                      children: [
                        Expanded(child: position),
                        const SizedBox(width: 12),
                        score,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRules(
    BuildContext context,
    CoordinatorRankingRule? rule,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: PiloFamilyTheme.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
    ),
    builder: (context) => Theme(
      data: PiloFamilyTheme.theme(Theme.of(context)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PiloFamilyTheme.connectorPast,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cómo se calcula',
                      style: PiloFamilyTheme.display(29),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('ranking-rules-close'),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Cuenta tu mejor gira de la temporada.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cada coordinador aparece una sola vez. Se elige la gira en la que sus publicaciones suman más puntos; no se mezclan los viajes. Los hitos antiguos sin un autor registrado no se pueden atribuir a un coordinador y no suman puntos.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  height: 1.4,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
              const SizedBox(height: 20),
              if (rule != null) ...[
                _ruleRow(
                  Icons.place_outlined,
                  'Cada hito publicado',
                  rule.hitoPoints,
                ),
                _ruleRow(
                  Icons.photo_outlined,
                  'Cada foto publicada',
                  rule.photoPoints,
                ),
                _ruleRow(
                  Icons.favorite_border_rounded,
                  'Cada Me gusta recibido',
                  rule.likePoints,
                ),
              ] else
                const Text(
                  'Carga el ranking para consultar su regla de puntuación.',
                  style: TextStyle(color: PiloFamilyTheme.secondary),
                ),
              const SizedBox(height: 16),
              const Text(
                'Los Me gusta corresponden a las fotos de tus hitos. Si hay empate en puntos, se comparan primero los Me gusta, luego los hitos y las fotos. Si todo coincide, se mantiene un orden estable.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.4,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _ruleRow(IconData icon, String label, int points) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, size: 22, color: PiloFamilyTheme.accentText),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '+$points',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _medal(int rank) {
  final (background, foreground) = switch (rank) {
    1 => (const Color(0xFFF6E6B8), const Color(0xFF75510D)),
    2 => (const Color(0xFFE1E4E8), const Color(0xFF49535F)),
    3 => (const Color(0xFFECD6C8), const Color(0xFF79472D)),
    _ => (PiloFamilyTheme.soft, PiloFamilyTheme.ink),
  };
  return Container(
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$rank',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    super.key,
    required this.entry,
    required this.name,
    required this.avatar,
    required this.isMe,
    this.podium = false,
  });
  final CoordinatorRankingEntry entry;
  final String name;
  final Widget avatar;
  final bool isMe, podium;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(15) > 21;
    final badge = entry.rank >= 4 && entry.rank <= 5
        ? 'Top 5'
        : entry.rank >= 6 && entry.rank <= 10
        ? 'Top 10'
        : null;
    return Semantics(
      label:
          '${isMe ? 'Tu puesto. ' : ''}Puesto ${entry.rank}, $name, ${entry.score} puntos, '
          '${entry.hitoCount} hitos, ${entry.photoCount} fotos, ${entry.likeCount} Me gusta${badge == null ? '' : ', $badge'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE4F5F0) : PiloFamilyTheme.soft,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (entry.rank <= 3)
                    _medal(entry.rank)
                  else
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${entry.rank}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: PiloFamilyTheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  avatar,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        if (isMe || badge != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                if (isMe) 'Tú',
                                if (badge != null) badge,
                              ].join(' · '),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: PiloFamilyTheme.accentText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!large) ...[const SizedBox(width: 8), _score()],
                ],
              ),
              if (large)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _score(),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 9,
                children: [
                  _metric(Icons.place_outlined, '${entry.hitoCount} hitos'),
                  _metric(Icons.photo_outlined, '${entry.photoCount} fotos'),
                  _metric(
                    Icons.favorite_border_rounded,
                    '${entry.likeCount} likes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _score() => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '${entry.score}',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
      ),
      const Text(
        'pts',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: PiloFamilyTheme.secondary,
        ),
      ),
    ],
  );
  Widget _metric(IconData icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: PiloFamilyTheme.secondary),
      const SizedBox(width: 4),
      Text(
        value,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: PiloFamilyTheme.secondary,
        ),
      ),
    ],
  );
}

class _RankingAvatar extends StatelessWidget {
  const _RankingAvatar({
    super.key,
    required this.name,
    required this.picture,
    required this.size,
  });
  final String name;
  final Future<Uint8List?> picture;
  final double size;
  @override
  Widget build(BuildContext context) {
    final words = name.split(' ').where((word) => word.isNotEmpty).toList();
    final initials = words
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    final fallback = Container(
      color: const Color(0xFFDCEAE5),
      alignment: Alignment.center,
      child: Text(
        initials,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size * .3,
          fontWeight: FontWeight.w600,
          color: PiloFamilyTheme.accentText,
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: FutureBuilder<Uint8List?>(
          future: picture,
          builder: (_, snapshot) => snapshot.data == null
              ? fallback
              : Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (_, child, frame, synchronous) =>
                      synchronous || frame != null ? child : fallback,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _PartialRankingNotice extends StatelessWidget {
  const _PartialRankingNotice();
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('ranking-partial'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F2EB),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: PiloFamilyTheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                  text: 'Ranking parcial\n',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: PiloFamilyTheme.ink,
                  ),
                ),
                TextSpan(
                  text:
                      'Hay publicaciones antiguas sin autor registrado. No se incluyen en este ranking.',
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.4,
              color: PiloFamilyTheme.secondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadingRanking extends StatelessWidget {
  const _LoadingRanking();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cargando ranking',
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.soft,
        borderRadius: BorderRadius.circular(36),
      ),
      child: const Column(
        children: [
          SizedBox.square(
            dimension: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: PiloFamilyTheme.accentText,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Preparando la clasificación…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: PiloFamilyTheme.secondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title, description;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: PiloFamilyTheme.soft,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: PiloFamilyTheme.accentText, size: 28),
        const SizedBox(height: 16),
        Text(title, style: PiloFamilyTheme.display(26)),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            height: 1.4,
            color: PiloFamilyTheme.secondary,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}
