import 'package:flutter/material.dart';
import 'dart:math';

/// An interactive analog clock with three draggable hands for setting the Kaalka encryption time seed.
class AnalogueClockPicker extends StatefulWidget {
  final int hours;
  final int minutes;
  final int seconds;
  final ValueChanged<({int hours, int minutes, int seconds})> onTimeChanged;

  const AnalogueClockPicker({
    super.key,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.onTimeChanged,
  });

  @override
  State<AnalogueClockPicker> createState() => _AnalogueClockPickerState();
}

class _AnalogueClockPickerState extends State<AnalogueClockPicker> {
  late int _hours;
  late int _minutes;
  late int _seconds;
  String? _dragging; // 'hour', 'minute', 'second', or null

  @override
  void initState() {
    super.initState();
    _hours = widget.hours;
    _minutes = widget.minutes;
    _seconds = widget.seconds;
  }

  void _handlePan(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // Convert to angle (0 = 12 o'clock, clockwise)
    double angle = atan2(dx, -dy);
    if (angle < 0) angle += 2 * pi;

    if (_dragging == 'hour') {
      _hours = ((angle / (2 * pi)) * 12).floor() % 12;
    } else if (_dragging == 'minute') {
      _minutes = ((angle / (2 * pi)) * 60).floor() % 60;
    } else if (_dragging == 'second') {
      _seconds = ((angle / (2 * pi)) * 60).floor() % 60;
    }

    setState(() {});
    widget.onTimeChanged((hours: _hours, minutes: _minutes, seconds: _seconds));
  }

  void _detectHand(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);

    // Determine which hand is closest based on distance from center
    if (dist > radius * 0.55) {
      _dragging = 'second'; // longest hand
    } else if (dist > radius * 0.35) {
      _dragging = 'minute';
    } else {
      _dragging = 'hour'; // shortest hand
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxWidth);
        return GestureDetector(
          onPanStart: (details) {
            _detectHand(details.localPosition, size);
            _handlePan(details.localPosition, size);
          },
          onPanUpdate: (details) => _handlePan(details.localPosition, size),
          onPanEnd: (_) => _dragging = null,
          child: CustomPaint(
            size: size,
            painter: _ClockPainter(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
              dragging: _dragging,
            ),
          ),
        );
      },
    );
  }
}

class _ClockPainter extends CustomPainter {
  final int hours;
  final int minutes;
  final int seconds;
  final String? dragging;

  _ClockPainter({
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.dragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw clock face
    final facePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, facePaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, borderPaint);

    // Draw outer glow
    final glowPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius + 3, glowPaint);

    // Draw tick marks
    for (int i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * pi - pi / 2;
      final isHour = i % 5 == 0;
      final innerR = isHour ? radius * 0.82 : radius * 0.88;
      final outerR = radius * 0.92;

      final p1 = Offset(center.dx + innerR * cos(angle), center.dy + innerR * sin(angle));
      final p2 = Offset(center.dx + outerR * cos(angle), center.dy + outerR * sin(angle));

      final tickPaint = Paint()
        ..color = isHour ? Colors.white54 : Colors.white24
        ..strokeWidth = isHour ? 2 : 1;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Draw hour numbers
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angle = (i / 12) * 2 * pi - pi / 2;
      final numPos = Offset(
        center.dx + radius * 0.72 * cos(angle) - 6,
        center.dy + radius * 0.72 * sin(angle) - 7,
      );
      textPainter.text = TextSpan(
        text: '$i',
        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, numPos);
    }

    // Draw hour hand
    _drawHand(
      canvas, center,
      (hours % 12 + minutes / 60) / 12 * 2 * pi - pi / 2,
      radius * 0.4, 4,
      dragging == 'hour' ? Colors.blueAccent : Colors.white,
    );

    // Draw minute hand
    _drawHand(
      canvas, center,
      (minutes / 60) * 2 * pi - pi / 2,
      radius * 0.6, 3,
      dragging == 'minute' ? Colors.blueAccent : Colors.white70,
    );

    // Draw second hand
    _drawHand(
      canvas, center,
      (seconds / 60) * 2 * pi - pi / 2,
      radius * 0.75, 1.5,
      dragging == 'second' ? Colors.blueAccent : Colors.redAccent,
    );

    // Draw center dot
    final dotPaint = Paint()..color = Colors.blueAccent;
    canvas.drawCircle(center, 5, dotPaint);
  }

  void _drawHand(Canvas canvas, Offset center, double angle, double length, double width, Color color) {
    final endpoint = Offset(
      center.dx + length * cos(angle),
      center.dy + length * sin(angle),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, endpoint, paint);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) {
    return oldDelegate.hours != hours ||
        oldDelegate.minutes != minutes ||
        oldDelegate.seconds != seconds ||
        oldDelegate.dragging != dragging;
  }
}
