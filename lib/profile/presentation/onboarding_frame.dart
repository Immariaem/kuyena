import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    this.step,
    this.onBack,
    this.welcome = false,
  });
  final String title, subtitle;
  final Widget child, footer;
  final int? step;
  final VoidCallback? onBack;
  final bool welcome;
  Widget _header(bool desktop) => Padding(
    padding: EdgeInsets.fromLTRB(
      desktop ? 40 : 26,
      desktop ? 36 : 12,
      desktop ? 40 : 26,
      32,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!desktop && kIsWeb && step == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: DesignStatusBar(),
          ),
        if (step != null || onBack != null) ...[
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Zurück',
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.chevron_left,
                    size: 30,
                    color: Colors.white,
                  ),
                )
              else
                const SizedBox(height: 44),
              const Spacer(),
              if (step != null)
                Flexible(
                  child: Text(
                    'Schritt $step von 7',
                    style: HomeDesign.text(
                      13,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (step != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Schritt $step von 7',
              child: Row(
                children: [
                  for (var i = 1; i <= 7; i++)
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i == 7 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: i <= step!
                              ? Colors.white
                              : Colors.white.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
        if (desktop) ...[
          Text(
            'Kuyena',
            style: HomeDesign.text(
              20,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 40),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: HomeDesign.text(
              desktop ? 42 : 36,
              color: Colors.white,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: HomeDesign.text(
            15,
            color: Colors.white,
            weight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        if (desktop && welcome) ...[
          const SizedBox(height: 36),
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: ColoredBox(
              color: Colors.white,
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  'assets/onboarding/welcome-mascot.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HomeDesign.red,
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, c) {
          final desktop = c.maxWidth >= 900;
          final content = Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey('onboarding-scroll-$title'),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          desktop ? 40 : 26,
                          28,
                          desktop ? 40 : 26,
                          24,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 40 : 26,
                        12,
                        desktop ? 40 : 26,
                        16,
                      ),
                      child: footer,
                    ),
                  ),
                ),
              ),
            ],
          );
          if (desktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: math.min(440, c.maxWidth * .35),
                  child: SingleChildScrollView(child: _header(true)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                    ),
                    child: ColoredBox(color: Colors.white, child: content),
                  ),
                ),
              ],
            );
          }
          if (welcome &&
              (c.maxHeight < 560 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3)) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _header(false),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(26),
                                child: child,
                              ),
                              Image.asset(
                                'assets/onboarding/welcome-mascot.png',
                                width: c.maxWidth,
                                height: c.maxWidth,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ColoredBox(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: footer,
                    ),
                  ),
                ),
              ],
            );
          }
          if (welcome) {
            return Column(
              children: [
                _header(false),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    child: LayoutBuilder(
                      builder: (context, b) {
                        final s = b.maxWidth / 412;
                        return ColoredBox(
                          color: Colors.white,
                          child: Stack(
                            children: [
                              Positioned(
                                left: -292 * s,
                                top: math.max(140, b.maxHeight - 480 * s),
                                width: 959 * s,
                                height: 959 * s,
                                child: Image.asset(
                                  'assets/onboarding/welcome-mascot.png',
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                ),
                              ),
                              Positioned(
                                left: 27,
                                right: 27,
                                top: 24,
                                child: child,
                              ),
                              Positioned(
                                left: 26,
                                right: 26,
                                bottom: 16,
                                child: SafeArea(top: false, child: footer),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }
          // A fixed footer stays reachable even on short screens and with a keyboard.
          // Header and questions share one scroll view on mobile to accommodate text scaling.
          return Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    key: ValueKey('onboarding-scroll-$title'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ColoredBox(
                          color: HomeDesign.red,
                          child: _header(false),
                        ),
                        ColoredBox(
                          color: HomeDesign.red,
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight: math.max(0, c.maxHeight - 350),
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ColoredBox(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 12, 26, 16),
                    child: footer,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
