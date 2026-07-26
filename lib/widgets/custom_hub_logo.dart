import 'package:flutter/material.dart';

class CustomHubLogo extends StatelessWidget {
  final double size;
  final Color color;
  const CustomHubLogo({
    super.key,
    required this.size,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HubPainter(color: color)),
    );
  }
}

class _HubPainter extends CustomPainter {
  final Color color;
  _HubPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.05
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final coreRadius = size.width * 0.18;
    final nodeRadius = size.width * 0.12;

    // Draw central core
    canvas.drawCircle(center, coreRadius, paint);

    // Draw 5 nodes: 12, 2, 4, 8, 10 o'clock
    final angles = [-90.0, -30.0, 30.0, 150.0, 210.0]; // Degrees

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke;

    final dist = (size.width / 2) - nodeRadius;

    for (var angle in angles) {
      final dx =
          dist *
          (angle == -90 ? 0 : (angle == -30 || angle == 30 ? 0.866 : -0.866));
      final dy =
          dist *
          (angle == -90 ? -1 : (angle == -30 || angle == 210 ? -0.5 : 0.5));
      final nodePos = Offset(center.dx + dx, center.dy + dy);

      canvas.drawLine(center, nodePos, linePaint);
      canvas.drawCircle(nodePos, nodeRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
