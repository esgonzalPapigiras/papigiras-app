import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../maps/trip_map_data.dart' show parseTripMapDate;
import 'pilo_family_theme.dart';

class PiloTripProgress extends StatefulWidget {
  const PiloTripProgress({
    super.key,
    required this.departure,
    required this.returnDate,
    this.now = DateTime.now,
    this.compact = false,
    this.summaryTitle,
    this.summarySubtitle,
  });

  final bool compact;
  final String? summaryTitle, summarySubtitle;
  final String departure;
  final String returnDate;
  final DateTime Function() now;

  @override
  State<PiloTripProgress> createState() => _PiloTripProgressState();
}

class _PiloTripProgressState extends State<PiloTripProgress> {
  late DateTime _today;
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    final now = widget.now();
    _today = _calendarDay(now);
    _scheduleMidnight(now);
    _lifecycle = AppLifecycleListener(onResume: _refreshToday);
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshToday() {
    final now = widget.now();
    final today = _calendarDay(now);
    if (today != _today) setState(() => _today = today);
    _scheduleMidnight(now);
  }

  void _scheduleMidnight(DateTime now) {
    _midnight?.cancel();
    final tomorrow = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(tomorrow.difference(now), _refreshToday);
  }

  // Use UTC only for comparing calendar days, independent of 23/25-hour days.
  static DateTime _calendarDay(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day);

  @override
  Widget build(BuildContext context) {
    final start = parseTripMapDate(widget.departure, '00:00');
    final end = parseTripMapDate(widget.returnDate, '00:00');
    if (widget.summaryTitle != null) return _summary(start, end);
    final style = Theme.of(context).textTheme.bodySmall;
    if (widget.compact &&
        start != null &&
        end != null &&
        !end.isBefore(start)) {
      return _bar(start, end);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (start != null && end != null && !end.isBefore(start)) ...[
          _bar(start, end),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dateLabel('Salida', start, style)),
            const SizedBox(width: 8),
            Expanded(
              child: _dateLabel('Regreso', end, style, align: TextAlign.end),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary(DateTime? start, DateTime? end) {
    final valid = start != null && end != null && !end.isBefore(start);
    final total = valid ? end.difference(start).inDays + 1 : 0;
    final day = valid
        ? (_today.difference(start).inDays + 1).clamp(0, total)
        : 0;
    final status = !valid
        ? 'Fechas por confirmar'
        : day == 0
        ? 'Por comenzar'
        : _today.isAfter(end)
        ? 'Finalizada'
        : 'En viaje';
    final progressLabel = status == 'En viaje' ? 'Día $day de $total' : status;
    const dateStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      height: 1.4,
      color: PiloFamilyTheme.onDark,
    );
    String shortDate(DateTime? date) {
      if (date == null) return 'Por confirmar';
      const months = [
        'ene.',
        'feb.',
        'mar.',
        'abr.',
        'may.',
        'jun.',
        'jul.',
        'ago.',
        'sept.',
        'oct.',
        'nov.',
        'dic.',
      ];
      final year = start != null && end != null && start.year != end.year
          ? ' ${date.year}'
          : '';
      return '${date.day} ${months[date.month - 1]}$year';
    }

    return DecoratedBox(
      key: const ValueKey('family-trip-summary'),
      decoration: BoxDecoration(
        color: PiloFamilyTheme.ink,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('Tu gira', style: dateStyle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF35483E)),
                      ),
                      child: Text(
                        status,
                        style: dateStyle.copyWith(color: PiloFamilyTheme.mint),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              widget.summaryTitle!,
              style: PiloFamilyTheme.display(28, color: Colors.white),
            ),
            if (widget.summarySubtitle?.isNotEmpty == true) ...[
              const SizedBox(height: 5),
              Text(
                widget.summarySubtitle!,
                key: const ValueKey('family-trip-title'),
                style: dateStyle.copyWith(fontSize: 12),
              ),
            ],
            const SizedBox(height: 17),
            LayoutBuilder(
              builder: (context, bounds) {
                final large =
                    MediaQuery.textScalerOf(context).scale(11) > 17 ||
                    bounds.maxWidth < 300;
                final labels = [
                  Text(
                    shortDate(start),
                    key: const ValueKey('family-trip-departure'),
                    semanticsLabel:
                        'Salida ${start == null ? "por confirmar" : DateFormat("dd/MM/yyyy").format(start)}',
                    style: dateStyle,
                  ),
                  if (valid)
                    Text(
                      progressLabel,
                      style: dateStyle.copyWith(
                        color: PiloFamilyTheme.mint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    shortDate(end),
                    key: const ValueKey('family-trip-return'),
                    semanticsLabel:
                        'Regreso ${end == null ? "por confirmar" : DateFormat("dd/MM/yyyy").format(end)}',
                    style: dateStyle,
                  ),
                ];
                return large
                    ? Wrap(spacing: 12, runSpacing: 5, children: labels)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < labels.length; i++)
                            Expanded(
                              child: Align(
                                alignment: i == 0
                                    ? Alignment.topLeft
                                    : i == labels.length - 1
                                    ? Alignment.topRight
                                    : Alignment.topCenter,
                                child: labels[i],
                              ),
                            ),
                        ],
                      );
              },
            ),
            if (valid) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: day / total,
                minHeight: 3,
                backgroundColor: const Color(0xFF3B4440),
                color: PiloFamilyTheme.mint,
                borderRadius: BorderRadius.circular(3),
                trackGap: 0,
                stopIndicatorRadius: 0,
                semanticsLabel: 'Avance de la gira',
                semanticsValue: progressLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(DateTime start, DateTime end) {
    final total = end.difference(start).inDays + 1;
    final day = (_today.difference(start).inDays + 1).clamp(0, total);
    final status = switch (day) {
      0 => 'Por comenzar',
      _ when _today.isAfter(end) => 'Finalizada',
      _ => 'Día $day de $total',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                status,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.4,
                  color: PiloFamilyTheme.accentText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _shortRange(start, end),
                semanticsLabel:
                    'Salida ${DateFormat('dd/MM/yyyy').format(start)}. '
                    'Regreso ${DateFormat('dd/MM/yyyy').format(end)}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.4,
                  color: PiloFamilyTheme.secondary,
                ),
              ),
            ],
          )
        else
          ExcludeSemantics(
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PiloFamilyTheme.accentText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: day / total,
          minHeight: widget.compact ? 3 : 5,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: PiloFamilyTheme.hairline,
          color: widget.compact
              ? PiloFamilyTheme.mint
              : PiloFamilyTheme.accentText,
          trackGap: 0,
          stopIndicatorRadius: 0,
          semanticsLabel: 'Avance de la gira',
          semanticsValue: status,
        ),
      ],
    );
  }

  String _shortRange(DateTime start, DateTime end) {
    const months = [
      'ene.',
      'feb.',
      'mar.',
      'abr.',
      'may.',
      'jun.',
      'jul.',
      'ago.',
      'sept.',
      'oct.',
      'nov.',
      'dic.',
    ];
    if (start.year != end.year) {
      return '${start.day} ${months[start.month - 1]} ${start.year} – '
          '${end.day} ${months[end.month - 1]} ${end.year}';
    }
    if (start.month != end.month) {
      return '${start.day} ${months[start.month - 1]} – '
          '${end.day} ${months[end.month - 1]}';
    }
    return '${start.day} – ${end.day} ${months[end.month - 1]}';
  }

  Widget _dateLabel(
    String label,
    DateTime? date,
    TextStyle? style, {
    TextAlign align = TextAlign.start,
  }) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: const TextStyle(
            color: PiloFamilyTheme.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: date == null
              ? 'Por confirmar'
              : DateFormat('dd/MM/yyyy').format(date),
        ),
      ],
    ),
    textAlign: align,
    style: style,
  );
}
