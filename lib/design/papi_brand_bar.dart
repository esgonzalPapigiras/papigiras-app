import 'package:flutter/material.dart';

/// Compact shared navigation header. The parent keeps PapiGiras' patterned
/// background; equal side slots keep the original logo centered at every role.
class PapiBrandBar extends StatelessWidget {
  const PapiBrandBar({
    super.key,
    this.onBack,
    this.onMenu,
    this.backTooltip = 'Volver',
  });

  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final String backTooltip;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SizedBox(
      key: const ValueKey('papi-brand-bar'),
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 48,
              child: onBack == null
                  ? null
                  : IconButton(
                      tooltip: backTooltip,
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 26,
                        color: Color(0xFF173F38),
                      ),
                    ),
            ),
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/logo-letras-papigiras.png',
                  height: 40,
                  fit: BoxFit.contain,
                  semanticLabel: 'PapiGiras',
                ),
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: onMenu == null
                  ? null
                  : IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: onMenu,
                      icon: const Icon(
                        Icons.menu,
                        size: 26,
                        color: Color(0xFF173F38),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
