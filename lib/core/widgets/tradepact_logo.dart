import 'package:flutter/material.dart';
import 'package:tradepact/core/theme/app_theme.dart';

/// TradePact brand logo rendered via CustomPainter.
/// Matches the SVG at assets/images/logo.svg.
///
/// [size]           — width & height of the bounding box
/// [showBackground] — draw the rounded-rect dark background (set false when
///                    the parent already provides the dark surface)
class TradePactLogo extends StatelessWidget {
  const TradePactLogo({
    super.key,
    this.size = 80,
    this.showBackground = true,
  });

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(showBackground: showBackground),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.showBackground});

  final bool showBackground;

  // All coordinates are in a 512×512 design space and scaled at paint time.
  static const _designSize = 512.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _designSize;

    double px(double v) => v * s;

    // ── Background ─────────────────────────────────────────────────────────
    if (showBackground) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(px(96)),
        ),
        Paint()
          ..color = AppColors.background
          ..style = PaintingStyle.fill,
      );
    }

    // ── Subtle grid lines ──────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = px(2);
    for (final gy in [160.0, 220.0, 280.0, 340.0]) {
      canvas.drawLine(Offset(px(72), px(gy)), Offset(px(440), px(gy)), gridPaint);
    }

    // ── Candles ────────────────────────────────────────────────────────────
    // 1 — Bearish (hollow outline)
    _candle(canvas, s,
        cx: 120,
        bodyTop: 272,
        bodyBottom: 330,
        wickTop: 252,
        wickBottom: 348,
        bullish: false);

    // 2 — Bullish small
    _candle(canvas, s,
        cx: 210,
        bodyTop: 243,
        bodyBottom: 325,
        wickTop: 218,
        wickBottom: 345,
        bullish: true);

    // 3 — Bullish medium
    _candle(canvas, s,
        cx: 300,
        bodyTop: 202,
        bodyBottom: 317,
        wickTop: 175,
        wickBottom: 340,
        bullish: true);

    // 4 — Bullish tall (with pact seal above)
    _candle(canvas, s,
        cx: 390,
        bodyTop: 158,
        bodyBottom: 310,
        wickTop: 148,
        wickBottom: 335,
        bullish: true);

    // ── "Pact" seal on candle 4 ────────────────────────────────────────────
    final sealStroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = px(5.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Dark fill so the circle sits cleanly over the wick
    canvas.drawCircle(
      Offset(px(390), px(113)),
      px(31),
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.fill,
    );
    // Gold ring
    canvas.drawCircle(Offset(px(390), px(113)), px(31), sealStroke);
    // Checkmark ✓
    canvas.drawPath(
      Path()
        ..moveTo(px(375), px(113))
        ..lineTo(px(386), px(125))
        ..lineTo(px(407), px(96)),
      sealStroke,
    );

    // ── Baseline ──────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(px(72), px(345)),
      Offset(px(440), px(345)),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = px(2.5),
    );
  }

  void _candle(
    Canvas canvas,
    double s, {
    required double cx,
    required double bodyTop,
    required double bodyBottom,
    required double wickTop,
    required double wickBottom,
    required bool bullish,
  }) {
    double px(double v) => v * s;
    const bodyWidth = 48.0;

    final wickPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = px(6)
      ..strokeCap = StrokeCap.round;

    // Upper wick
    canvas.drawLine(
      Offset(px(cx), px(wickTop)),
      Offset(px(cx), px(bodyTop)),
      wickPaint,
    );
    // Lower wick
    canvas.drawLine(
      Offset(px(cx), px(bodyBottom)),
      Offset(px(cx), px(wickBottom)),
      wickPaint,
    );

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        px(cx - bodyWidth / 2),
        px(bodyTop),
        px(bodyWidth),
        px(bodyBottom - bodyTop),
      ),
      Radius.circular(px(5)),
    );

    if (bullish) {
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill,
      );
    } else {
      // Bearish: dark fill + gold stroke
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = AppColors.surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => false;
}
