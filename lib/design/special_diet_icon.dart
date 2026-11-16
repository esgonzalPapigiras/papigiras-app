import 'package:flutter/material.dart';

/// Same amber cutlery for the home summary, diet list and passenger roster.
class SpecialDietIcon extends StatelessWidget {
  const SpecialDietIcon({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: compact
        ? const Icon(
            Icons.restaurant_rounded,
            size: 17,
            color: Color(0xFFA86600),
          )
        : Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2D7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 22,
              color: Color(0xFFA86600),
            ),
          ),
  );
}
