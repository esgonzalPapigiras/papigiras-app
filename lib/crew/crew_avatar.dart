import 'package:flutter/material.dart';
import '../design/apple_design_trial.dart';

/// Local vector illustrations. These represent roles, not actual vehicles/people.
class CrewAvatar extends StatelessWidget {
  const CrewAvatar({super.key, required this.bus, this.size = 64});
  final bool bus;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: bus ? 'Ilustración de bus' : 'Avatar de conductor',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bus ? const Color(0xFFD7EDE5) : const Color(0xFFEEF2F8),
        borderRadius: bus ? BorderRadius.circular(22) : null,
        shape: bus ? BoxShape.rectangle : BoxShape.circle,
      ),
      child: CustomPaint(painter: _CrewIllustration(bus)),
    ),
  );
}

class _CrewIllustration extends CustomPainter {
  const _CrewIllustration(this.bus);
  final bool bus;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 80);
    final fill = Paint()..color = AppleTrialColors.ink;
    void rounded(Rect rect, double radius, Color color) {
      fill.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        fill,
      );
    }

    if (bus) {
      rounded(const Rect.fromLTWH(19, 57, 9, 10), 3, AppleTrialColors.ink);
      rounded(const Rect.fromLTWH(52, 57, 9, 10), 3, AppleTrialColors.ink);
      rounded(const Rect.fromLTWH(14, 27, 5, 14), 2, AppleTrialColors.accent);
      rounded(const Rect.fromLTWH(61, 27, 5, 14), 2, AppleTrialColors.accent);
      rounded(const Rect.fromLTWH(18, 13, 44, 49), 12, AppleTrialColors.accent);
      rounded(const Rect.fromLTWH(23, 23, 34, 25), 6, const Color(0xFFC1E4E9));
      rounded(const Rect.fromLTWH(29, 17, 22, 3), 1.5, const Color(0xFFFFFFFF));
      rounded(const Rect.fromLTWH(24, 52, 7, 4), 2, const Color(0xFFFFD66A));
      rounded(const Rect.fromLTWH(49, 52, 7, 4), 2, const Color(0xFFFFD66A));
      rounded(const Rect.fromLTWH(35, 53, 10, 3), 1, AppleTrialColors.ink);
      rounded(const Rect.fromLTWH(39, 24, 2, 23), 1, AppleTrialColors.accent);
      final glint = Path()
        ..moveTo(27, 27)
        ..lineTo(36, 27)
        ..lineTo(27, 36)
        ..close();
      fill.color = const Color(0xFFEFF9FA);
      canvas.drawPath(glint, fill);
    } else {
      fill.color = const Color(0xFF7387A4);
      canvas.drawCircle(const Offset(40, 32), 10, fill);
      final shirt = Path()
        ..moveTo(19, 65)
        ..quadraticBezierTo(19, 45, 40, 45)
        ..quadraticBezierTo(61, 45, 61, 65)
        ..close();
      canvas.drawPath(shirt, fill);
      rounded(const Rect.fromLTWH(27, 19, 26, 7), 3, AppleTrialColors.ink);
      rounded(const Rect.fromLTWH(33, 24, 23, 4), 2, AppleTrialColors.ink);
      final wheel = Paint()
        ..color = AppleTrialColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(const Offset(40, 60), 13, wheel);
      canvas.drawLine(const Offset(28, 57), const Offset(40, 61), wheel);
      canvas.drawLine(const Offset(52, 57), const Offset(40, 61), wheel);
      canvas.drawLine(const Offset(40, 61), const Offset(40, 72), wheel);
      fill.color = const Color(0xFFFFD66A);
      canvas.drawCircle(const Offset(40, 60), 3, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CrewIllustration oldDelegate) =>
      bus != oldDelegate.bus;
}
