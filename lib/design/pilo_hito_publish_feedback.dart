import 'package:flutter/material.dart';
import 'package:papigiras_app/voice/hito_publish_progress.dart';
import 'pilo_family_theme.dart';

/// Reports the publisher's actual stage; transfer completion is not success.
class PiloHitoPublishingFeedback extends StatelessWidget {
  const PiloHitoPublishingFeedback({super.key, required this.progress});
  final HitoPublishProgress progress;

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Dialog(
      backgroundColor: PiloFamilyTheme.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: PiloFamilyTheme.mint,
                child: Icon(
                  Icons.north_east_rounded,
                  color: PiloFamilyTheme.ink,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Publicando hito',
              style: PiloFamilyTheme.display(28, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                progress.stage,
                key: const ValueKey('hito-upload-stage'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: PiloFamilyTheme.onDark,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.fraction,
                color: PiloFamilyTheme.mint,
                backgroundColor: const Color(0xFF353B38),
                minHeight: 6,
                semanticsLabel: progress.stage,
              ),
            ),
            if (progress.fraction != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${(progress.fraction! * 100).round()} %',
                  key: const ValueKey('hito-upload-percent'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PiloFamilyTheme.onDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

SnackBar piloHitoPublishedSnackBar() => SnackBar(
  key: const ValueKey('hito-published-confirmation'),
  behavior: SnackBarBehavior.floating,
  backgroundColor: PiloFamilyTheme.ink,
  elevation: 0,
  duration: const Duration(seconds: 4),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  content: Semantics(
    liveRegion: true,
    child: Row(
      children: [
        const CircleAvatar(
          radius: 19,
          backgroundColor: PiloFamilyTheme.mint,
          child: Icon(Icons.check_rounded, color: PiloFamilyTheme.ink),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hito publicado',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Un nuevo recuerdo de la gira.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.3,
                  color: PiloFamilyTheme.onDark,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
