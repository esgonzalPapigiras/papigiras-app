import 'package:flutter/material.dart';

class LabMap extends StatelessWidget {
  const LabMap({super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 220, margin: const EdgeInsets.symmetric(horizontal: 16),
    clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: const Color(0xffedf2e7), borderRadius: BorderRadius.circular(16)),
    child: Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _RoutePainter()),
      const Center(child: Icon(Icons.directions_bus_filled, size: 42, color: Colors.teal)),
      const Positioned(left: 12, bottom: 12, child: Chip(label: Text('Mapa ficticio · sin GPS', style: TextStyle(fontSize: 12)))),
    ]));
}
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roads = Paint()..color=Colors.white..strokeWidth=12;
    for (var i=-1;i<6;i++) { canvas.drawLine(Offset(i*90,0),Offset(i*90+90,size.height),roads); }
    final river = Path()..moveTo(size.width*.7,0)..cubicTo(size.width*.2,80,size.width*.9,150,size.width*.5,size.height);
    canvas.drawPath(river,Paint()..color=const Color(0xffb0dce6)..strokeWidth=35..style=PaintingStyle.stroke);
    final route=Path()..moveTo(25,size.height-25)..cubicTo(size.width*.3,25,size.width*.7,180,size.width-25,30);
    canvas.drawPath(route,Paint()..color=Colors.teal..strokeWidth=4..style=PaintingStyle.stroke);
    canvas.drawCircle(const Offset(25,195),7,Paint()..color=Colors.teal);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
