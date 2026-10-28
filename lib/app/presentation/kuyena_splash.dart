import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'kuyena_components.dart';

class KuyenaSplash extends StatefulWidget {
  const KuyenaSplash({
    super.key,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 1400),
  });
  final VoidCallback onFinished;
  final Duration duration;
  @override
  State<KuyenaSplash> createState() => _KuyenaSplashState();
}

class _KuyenaSplashState extends State<KuyenaSplash> {
  Timer? _timer;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Semantics(
      label: 'Kuyena. Open app.',
      button: true,
      child: GestureDetector(
        onTap: _finish,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, c) {
            final s = math.max(c.maxWidth / 412, c.maxHeight / 917);
            final logoScale = math.min(c.maxWidth / 412, 1.6);
            // Keep the original vector canvas and letter bounds; no font substitutes.
            final letters = [
              ('e0a42.svg', 19.982, 404.03, 82.8455, 87.5923),
              ('f681a.svg', 82.565, 416.868, 77.5316, 74.6057),
              ('815c6.svg', 141.6456, 416.777, 76.2775, 96.6128),
              ('4dc97.svg', 203.116, 415.952, 72.6057, 76.4569),
              ('750f8.svg', 260.714, 416.227, 77.9792, 75.3355),
              ('feccc.svg', 319.1764, 416.135, 73.3817, 75.3821),
            ];
            return ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: (c.maxWidth - 412 * s) / 2 - 90 * s,
                    top: (c.maxHeight - 917 * s) / 2 - 106 * s,
                    child: DesignAsset(
                      '97354.svg',
                      width: 712.5 * s,
                      height: 1141.5 * s,
                    ),
                  ),
                  for (final l in letters)
                    Positioned(
                      left:
                          (c.maxWidth - 412 * logoScale) / 2 + l.$2 * logoScale,
                      top: c.maxHeight / 2 + (l.$3 - 458.5) * logoScale,
                      child: DesignAsset(
                        l.$1,
                        width: l.$4 * logoScale,
                        height: l.$5 * logoScale,
                      ),
                    ),
                  if (kIsWeb && c.maxWidth < 900)
                    const Positioned(
                      left: 26,
                      right: 26,
                      top: 12,
                      child: DesignStatusBar(),
                    ),
                  if (kIsWeb && c.maxWidth < 900)
                    Positioned(
                      bottom: 24,
                      left: c.maxWidth / 2 - 64,
                      child: Container(
                        width: 128,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF382331),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
