import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../periods/domain/calendar_date.dart';
import 'home_design.dart';

/// The same Home features arranged for a wide browser window.
class HomeDesktopLayout extends StatelessWidget {
  const HomeDesktopLayout({
    super.key,
    required this.selectedDate,
    required this.hero,
    required this.information,
    required this.onToday,
    required this.onCalendar,
    required this.onLog,
    required this.onForYou,
    required this.onCycle,
    required this.onDemo,
  });

  final CalendarDate selectedDate;
  final Widget hero;
  final Widget information;
  final VoidCallback onToday;
  final VoidCallback onCalendar;
  final VoidCallback onLog;
  final VoidCallback onForYou;
  final VoidCallback onCycle;
  final VoidCallback onDemo;

  Widget _navigation(
    String label,
    String icon,
    VoidCallback onTap, {
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? HomeDesign.pink : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('home-nav-$label'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/home/$icon.svg',
                  width: 22,
                  height: 22,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    label,
                    style: HomeDesign.text(
                      16,
                      color: selected ? HomeDesign.red : HomeDesign.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1200;
    return Row(
      key: const ValueKey('desktop-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('desktop-navigation'),
          width: compact ? 192 : 224,
          child: ColoredBox(
            color: HomeDesign.palePink,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Kuyena', style: HomeDesign.text(32)),
                          const SizedBox(height: 6),
                          Text(
                            'Dein Zyklus im Überblick',
                            style: HomeDesign.text(
                              13,
                              color: HomeDesign.muted,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 36),
                          _navigation('Home', 'home', onToday, selected: true),
                          _navigation('Calendar', 'calendar', onCalendar),
                          _navigation('For you', 'compass', onForYou),
                          _navigation('Cycle', 'user', onCycle),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('home-log-button'),
                    onPressed: onLog,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeDesign.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: SvgPicture.asset(
                      'assets/home/log-plus.svg',
                      width: 31.5,
                      height: 31.5,
                      excludeFromSemantics: true,
                    ),
                    label: Text(
                      'Log',
                      style: HomeDesign.text(17, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onDemo,
                    child: Text(
                      'Designvorschau',
                      style: HomeDesign.text(12, color: HomeDesign.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('desktop-home-scroll'),
            padding: EdgeInsets.all(compact ? 28 : 40),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hey, girl!', style: HomeDesign.text(40)),
                              const SizedBox(height: 4),
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatFullDate(selectedDate.value),
                                style: HomeDesign.text(
                                  16,
                                  color: HomeDesign.muted,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: onDemo,
                              child: Text('Demo', style: HomeDesign.text(13)),
                            ),
                            OutlinedButton(
                              onPressed: onToday,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HomeDesign.red,
                                side: const BorderSide(color: HomeDesign.pink),
                              ),
                              child: Text('Heute', style: HomeDesign.text(14)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            key: const ValueKey('desktop-cycle-panel'),
                            borderRadius: BorderRadius.circular(32),
                            child: ColoredBox(color: Colors.white, child: hero),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          key: const ValueKey('desktop-information-panel'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Dein Überblick',
                                style: HomeDesign.text(
                                  24,
                                  color: HomeDesign.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Deine Einträge und eine vorläufige Phasenschätzung. Bewegungsideen bleiben allgemeine Beispiele.',
                                style: HomeDesign.text(
                                  14,
                                  color: HomeDesign.muted,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 22),
                              information,
                              const SizedBox(height: 24),
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dein Tagebuch',
                                        style: HomeDesign.text(22),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Perioden mit Beginn und optionalem Ende ansehen und bearbeiten.',
                                        style: HomeDesign.text(
                                          15,
                                          color: HomeDesign.muted,
                                          weight: FontWeight.w600,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton.icon(
                                        onPressed: onCalendar,
                                        icon: SvgPicture.asset(
                                          'assets/home/calendar.svg',
                                          width: 22,
                                          height: 22,
                                          excludeFromSemantics: true,
                                        ),
                                        label: Text(
                                          'Verlauf öffnen',
                                          style: HomeDesign.text(15),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
