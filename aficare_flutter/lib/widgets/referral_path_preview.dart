import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Compact animated graphic that visualises the referral data path.
///
/// Shows three steps (You → Clinic → New provider) with a traveling
/// dot that loops along the dashed connector.  Purely decorative —
/// no interactivity, just visual polish for the login brand panel.
class ReferralPathPreview extends StatefulWidget {
  const ReferralPathPreview({super.key});

  @override
  State<ReferralPathPreview> createState() => _ReferralPathPreviewState();
}

class _ReferralPathPreviewState extends State<ReferralPathPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return CustomPaint(
          size: const Size(260, 52),
          painter: _PathPainter(progress: t),
        );
      },
    );
  }
}

class _PathPainter extends CustomPainter {
  const _PathPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    final nodeRadius = 12.0;
    final dotRadius = 4.0;

    // ── Nodes ──────────────────────────────────────────────────────
    final positions = [
      Offset(nodeRadius + 4, cy),
      Offset(w / 2, cy),
      Offset(w - nodeRadius - 4, cy),
    ];
    final labels = ['You', 'Clinic', 'Provider'];
    final iconData = [
      Icons.person_outline,
      Icons.local_hospital_outlined,
      Icons.medical_services_outlined,
    ];

    // ── Dashed line ────────────────────────────────────────────────
    final dashPaint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < positions.length - 1; i++) {
      final start = positions[i] + Offset(nodeRadius + 2, 0);
      final end = positions[i + 1] - Offset(nodeRadius + 2, 0);
      _drawDashedLine(canvas, start, end, dashPaint, dashLen: 5, gapLen: 4);
    }

    // ── Traveling dot ──────────────────────────────────────────────
    final pathLen = w - nodeRadius * 2 - 8;
    final dotX = 6 + pathLen * progress;
    final dotPaint = Paint()..color = AppColors.canopy;
    canvas.drawCircle(Offset(dotX, cy), dotRadius, dotPaint);

    // ── Node circles + labels ──────────────────────────────────────
    final bgPaint = Paint()..color = AppColors.canopyPale;

    for (var i = 0; i < positions.length; i++) {
      canvas.drawCircle(positions[i], nodeRadius, bgPaint);

      final icon = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData[i].codePoint),
          style: TextStyle(
            fontSize: 13,
            fontFamily: iconData[i].fontFamily,
            color: AppColors.canopy,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(
        canvas,
        Offset(
          positions[i].dx - icon.width / 2,
          positions[i].dy - icon.height / 2,
        ),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(positions[i].dx - tp.width / 2, cy + nodeRadius + 6),
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashLen,
    required double gapLen,
  }) {
    final total = (end - start).distance;
    final dir = (end - start) / total;
    double dist = 0;
    while (dist < total) {
      final s = start + dir * dist;
      final e = start + dir * math.min(dist + dashLen, total);
      canvas.drawLine(s, e, paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.progress != progress;
}
