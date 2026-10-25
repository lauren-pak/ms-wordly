import 'dart:math';

import 'package:flutter/material.dart';

import '../services/rewards.dart';

/// The plush bunny mascot, wearing whatever is equipped.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 160, this.equipped = const {}});

  final double size;
  final Map<Slot, String> equipped;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _BunnyPainter(equipped)),
  );
}

const _fur = Color(0xFFEEDDC7);
const _furLight = Color(0xFFFBF3E8);
const _furShade = Color(0xFFD8C0A3);
const _innerEar = Color(0xFFF5C6CC);
const _blush = Color(0x88F59AAE);
const _ink = Color(0xFF2E2622);
const _nose = Color(0xFFE48C9C);

class _BunnyPainter extends CustomPainter {
  _BunnyPainter(this.equipped);

  final Map<Slot, String> equipped;
  late Canvas c;
  late double s;

  Offset p(double x, double y) => Offset(x * s, y * s);

  void oval(
    double cx,
    double cy,
    double w,
    double h,
    Paint paint, {
    double rotate = 0,
  }) {
    c.save();
    c.translate(cx * s, cy * s);
    c.rotate(rotate);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * s, height: h * s),
      paint,
    );
    c.restore();
  }

  Paint fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  /// Soft fur shading for a shape of radius [r], drawn at the origin.
  Paint plush(double r) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.9,
      colors: const [_furLight, _fur, _furShade],
      stops: const [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * s));

  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * s
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    s = size.shortestSide;

    oval(0.5, 0.955, 0.5, 0.05, fill(const Color(0x14000000)));
    if (equipped[Slot.held] == 'balloon') _balloon();

    // Body, feet, and arms.
    oval(0.5, 0.75, 0.46, 0.36, plush(0.25));
    for (final side in [-1.0, 1.0]) {
      oval(0.5 + side * 0.11, 0.91, 0.16, 0.09, plush(0.1));
      oval(
        0.5 + side * 0.11,
        0.915,
        0.06,
        0.035,
        fill(_innerEar.withValues(alpha: 0.7)),
      );
      oval(
        0.5 + side * 0.2,
        0.74,
        0.11,
        0.18,
        plush(0.12),
        rotate: side * 0.35,
      );
    }

    _neck(equipped[Slot.neck]);

    // Long floppy ears drape down over the shoulders.
    for (final side in [-1.0, 1.0]) {
      oval(
        0.5 + side * 0.255,
        0.5,
        0.15,
        0.46,
        plush(0.26),
        rotate: -side * 0.12,
      );
      oval(
        0.5 + side * 0.262,
        0.56,
        0.075,
        0.3,
        fill(_innerEar),
        rotate: -side * 0.12,
      );
    }

    // Head with a soft, slightly squashed shape.
    oval(0.5, 0.42, 0.54, 0.46, plush(0.3));

    // Face.
    for (final side in [-1.0, 1.0]) {
      oval(0.5 + side * 0.15, 0.5, 0.08, 0.045, fill(_blush));
      oval(0.5 + side * 0.075, 0.445, 0.042, 0.048, fill(_ink));
      oval(0.5 + side * 0.075 - 0.008, 0.437, 0.013, 0.013, fill(Colors.white));
    }
    oval(0.5, 0.483, 0.036, 0.024, fill(_nose));
    final mouth = Path()
      ..moveTo(0.475 * s, 0.505 * s)
      ..quadraticBezierTo(0.4875 * s, 0.52 * s, 0.5 * s, 0.503 * s)
      ..quadraticBezierTo(0.5125 * s, 0.52 * s, 0.525 * s, 0.505 * s);
    c.drawPath(mouth, stroke(_ink, 0.008));

    _face(equipped[Slot.face]);
    _head(equipped[Slot.head]);
    _held(equipped[Slot.held]);
  }

  void _neck(String? id) {
    switch (id) {
      case 'scarf':
        final red = fill(const Color(0xFFE5737D));
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p(0.5, 0.625),
              width: 0.36 * s,
              height: 0.07 * s,
            ),
            Radius.circular(0.035 * s),
          ),
          red,
        );
        oval(0.6, 0.71, 0.07, 0.15, red, rotate: -0.25);
        for (var i = 0; i < 3; i++) {
          c.drawLine(
            p(0.58 + i * 0.018, 0.775),
            p(0.585 + i * 0.018, 0.8),
            stroke(const Color(0xFFE5737D), 0.008),
          );
        }
      case 'bowtie':
        _bow(0.5, 0.665, 0.14, const Color(0xFF5B8DEF));
      case 'pearls':
        for (var i = 0; i <= 8; i++) {
          final t = i / 8;
          final x = 0.36 + t * 0.28;
          final y = 0.62 + sin(t * pi) * 0.05;
          oval(x, y, 0.035, 0.035, fill(const Color(0xFFFFFDF8)));
          oval(x - 0.006, y - 0.006, 0.01, 0.01, fill(Colors.white));
        }
    }
  }

  void _face(String? id) {
    switch (id) {
      case 'glasses':
        final frame = stroke(const Color(0xFF6B4F3A), 0.012);
        for (final side in [-1.0, 1.0]) {
          c.drawCircle(p(0.5 + side * 0.08, 0.445), 0.055 * s, frame);
        }
        c.drawLine(p(0.47, 0.44), p(0.53, 0.44), frame);
      case 'hearts':
        for (final side in [-1.0, 1.0]) {
          _heart(0.5 + side * 0.08, 0.45, 0.11, const Color(0xCCF06292));
        }
        c.drawLine(
          p(0.47, 0.435),
          p(0.53, 0.435),
          stroke(const Color(0xFFF06292), 0.01),
        );
      case 'stars':
        _star(0.33, 0.43, 0.035, const Color(0xFFFFC94D));
        _star(0.68, 0.53, 0.03, const Color(0xFFFFC94D));
        _star(0.64, 0.41, 0.02, const Color(0xFFFF9FB5));
    }
  }

  void _head(String? id) {
    switch (id) {
      case 'bow':
        _bow(0.64, 0.22, 0.17, const Color(0xFFF48FB1), rotate: 0.35);
      case 'party_hat':
        c.save();
        c.translate(0.56 * s, 0.13 * s);
        c.rotate(0.25);
        final cone = Path()
          ..moveTo(0, -0.12 * s)
          ..lineTo(-0.08 * s, 0.08 * s)
          ..lineTo(0.08 * s, 0.08 * s)
          ..close();
        c.drawPath(cone, fill(const Color(0xFF8E7CF0)));
        c.clipPath(cone);
        for (var i = 0; i < 4; i++) {
          c.drawLine(
            Offset(-0.1 * s, (-0.06 + i * 0.05) * s),
            Offset(0.1 * s, (-0.1 + i * 0.05) * s),
            stroke(const Color(0xFFFFD166), 0.018),
          );
        }
        c.restore();
        c.save();
        c.translate(0.56 * s, 0.13 * s);
        c.rotate(0.25);
        c.drawCircle(
          Offset(0, -0.125 * s),
          0.025 * s,
          fill(const Color(0xFFFF8FAB)),
        );
        c.restore();
      case 'beanie':
        final hat = Path()
          ..moveTo(0.25 * s, 0.3 * s)
          ..cubicTo(0.25 * s, 0.06 * s, 0.75 * s, 0.06 * s, 0.75 * s, 0.3 * s)
          ..close();
        c.drawPath(hat, fill(const Color(0xFFEF5F6F)));
        for (final d in [
          [0.38, 0.2],
          [0.5, 0.15],
          [0.62, 0.2],
          [0.44, 0.25],
          [0.56, 0.25],
          [0.5, 0.21],
        ]) {
          oval(d[0], d[1], 0.014, 0.022, fill(const Color(0xFFFFE08A)));
        }
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p(0.5, 0.29),
              width: 0.52 * s,
              height: 0.06 * s,
            ),
            Radius.circular(0.03 * s),
          ),
          fill(const Color(0xFFD94B5C)),
        );
        for (final leaf in [-0.35, 0.0, 0.35]) {
          oval(
            0.5 + leaf * 0.08,
            0.09,
            0.04,
            0.08,
            fill(const Color(0xFF6CC071)),
            rotate: leaf * 2,
          );
        }
      case 'flowers':
        const colors = [
          Color(0xFFFFB3C7),
          Color(0xFFFFE08A),
          Color(0xFFB8E0FF),
          Color(0xFFD7B8FF),
        ];
        for (var i = 0; i < 7; i++) {
          final t = i / 6;
          final x = 0.3 + t * 0.4;
          final y = 0.24 - sin(t * pi) * 0.06;
          if (i.isOdd) {
            oval(
              x,
              y + 0.012,
              0.05,
              0.03,
              fill(const Color(0xFF7CC47F)),
              rotate: 0.5,
            );
          }
          for (var k = 0; k < 5; k++) {
            final a = k * 2 * pi / 5;
            oval(
              x + cos(a) * 0.017,
              y + sin(a) * 0.017,
              0.028,
              0.028,
              fill(colors[i % colors.length]),
            );
          }
          oval(x, y, 0.016, 0.016, fill(const Color(0xFFFFC94D)));
        }
      case 'crown':
        final gold = fill(const Color(0xFFFFC94D));
        final crown = Path()
          ..moveTo(0.4 * s, 0.2 * s)
          ..lineTo(0.4 * s, 0.11 * s)
          ..lineTo(0.45 * s, 0.155 * s)
          ..lineTo(0.5 * s, 0.09 * s)
          ..lineTo(0.55 * s, 0.155 * s)
          ..lineTo(0.6 * s, 0.11 * s)
          ..lineTo(0.6 * s, 0.2 * s)
          ..close();
        c.drawPath(crown, gold);
        for (final x in [0.4, 0.5, 0.6]) {
          c.drawCircle(
            p(x, x == 0.5 ? 0.09 : 0.11),
            0.014 * s,
            fill(const Color(0xFFFF8FAB)),
          );
        }
        oval(0.5, 0.175, 0.03, 0.03, fill(const Color(0xFF7FC8F8)));
    }
  }

  void _held(String? id) {
    switch (id) {
      case 'carrot':
        c.save();
        c.translate(0.73 * s, 0.73 * s);
        c.rotate(-0.6);
        final body = Path()
          ..moveTo(-0.035 * s, -0.06 * s)
          ..quadraticBezierTo(0, 0.12 * s, 0.035 * s, -0.06 * s)
          ..close();
        c.drawPath(body, fill(const Color(0xFFFF9F43)));
        for (final a in [-0.4, 0.0, 0.4]) {
          c.save();
          c.translate(0, -0.06 * s);
          c.rotate(a);
          c.drawOval(
            Rect.fromCenter(
              center: Offset(0, -0.03 * s),
              width: 0.02 * s,
              height: 0.06 * s,
            ),
            fill(const Color(0xFF6CC071)),
          );
          c.restore();
        }
        c.restore();
      case 'coffee':
        final cup = Path()
          ..moveTo(0.68 * s, 0.68 * s)
          ..lineTo(0.79 * s, 0.68 * s)
          ..lineTo(0.775 * s, 0.8 * s)
          ..lineTo(0.695 * s, 0.8 * s)
          ..close();
        c.drawPath(cup, fill(Colors.white));
        c.drawRect(
          Rect.fromLTRB(0.685 * s, 0.715 * s, 0.785 * s, 0.76 * s),
          fill(const Color(0xFFB98B6E)),
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(0.67 * s, 0.66 * s, 0.8 * s, 0.69 * s),
            Radius.circular(0.01 * s),
          ),
          fill(const Color(0xFFF3EDE6)),
        );
        for (final x in [0.715, 0.755]) {
          final steam = Path()
            ..moveTo(x * s, 0.645 * s)
            ..quadraticBezierTo((x - 0.015) * s, 0.62 * s, x * s, 0.6 * s);
          c.drawPath(steam, stroke(const Color(0x66B0A090), 0.008));
        }
      case 'balloon':
        // Drawn first so it floats behind; only the string end shows here.
        break;
      case 'book':
        c.save();
        c.translate(0.74 * s, 0.74 * s);
        c.rotate(-0.15);
        final r = Rect.fromCenter(
          center: Offset.zero,
          width: 0.13 * s,
          height: 0.16 * s,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(0.012 * s)),
          fill(const Color(0xFF5B8DEF)),
        );
        c.drawRect(
          Rect.fromLTRB(
            r.right - 0.02 * s,
            r.top + 0.01 * s,
            r.right - 0.005 * s,
            r.bottom - 0.01 * s,
          ),
          fill(const Color(0xFFFFF8E7)),
        );
        c.drawLine(
          Offset(r.left + 0.025 * s, r.top + 0.045 * s),
          Offset(r.right - 0.035 * s, r.top + 0.045 * s),
          stroke(const Color(0xFFFFD166), 0.012),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: 'Aa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 0.045 * s,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(-0.035 * s, -0.005 * s));
        c.restore();
    }
  }

  void _balloon() {
    final string = Path()
      ..moveTo(0.72 * s, 0.76 * s)
      ..quadraticBezierTo(0.86 * s, 0.55 * s, 0.82 * s, 0.33 * s);
    c.drawPath(string, stroke(const Color(0xFF9E9E9E), 0.006));
    oval(0.82, 0.2, 0.2, 0.24, fill(const Color(0xFFFF7A93)));
    oval(0.78, 0.15, 0.04, 0.07, fill(const Color(0x66FFFFFF)), rotate: 0.4);
    final knot = Path()
      ..moveTo(0.81 * s, 0.33 * s)
      ..lineTo(0.83 * s, 0.33 * s)
      ..lineTo(0.82 * s, 0.315 * s)
      ..close();
    c.drawPath(knot, fill(const Color(0xFFFF7A93)));
  }

  void _bow(double cx, double cy, double w, Color color, {double rotate = 0}) {
    c.save();
    c.translate(cx * s, cy * s);
    c.rotate(rotate);
    final paint = fill(color);
    for (final side in [-1.0, 1.0]) {
      final wing = Path()
        ..moveTo(0, 0)
        ..lineTo(side * w / 2 * s, -w * 0.32 * s)
        ..quadraticBezierTo(
          side * w * 0.62 * s,
          0,
          side * w / 2 * s,
          w * 0.32 * s,
        )
        ..close();
      c.drawPath(wing, paint);
    }
    c.drawCircle(
      Offset.zero,
      w * 0.14 * s,
      fill(Color.lerp(color, Colors.black, 0.12)!),
    );
    c.restore();
  }

  void _heart(double cx, double cy, double w, Color color) {
    final h = Path()
      ..moveTo(cx * s, (cy + w * 0.35) * s)
      ..cubicTo(
        (cx - w * 0.6) * s,
        (cy - w * 0.05) * s,
        (cx - w * 0.3) * s,
        (cy - w * 0.55) * s,
        cx * s,
        (cy - w * 0.2) * s,
      )
      ..cubicTo(
        (cx + w * 0.3) * s,
        (cy - w * 0.55) * s,
        (cx + w * 0.6) * s,
        (cy - w * 0.05) * s,
        cx * s,
        (cy + w * 0.35) * s,
      )
      ..close();
    c.drawPath(h, fill(color));
  }

  void _star(double cx, double cy, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = p(cx + cos(a) * rad, cy + sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), fill(color));
  }

  @override
  bool shouldRepaint(_BunnyPainter old) =>
      old.equipped.toString() != equipped.toString();
}
