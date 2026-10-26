import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../periods/application/period_diary.dart';
import '../../periods/domain/calendar_date.dart';
import '../../periods/presentation/period_home_page.dart';
import 'home_design.dart';
import 'curved_date_slider.dart';
import 'home_desktop_layout.dart';

/// Home is a design preview. Sample predictions never enter the diary.
class KuyenaHomePage extends StatefulWidget {
  const KuyenaHomePage({super.key, required this.diary});

  final PeriodDiary diary;

  @override
  State<KuyenaHomePage> createState() => _KuyenaHomePageState();
}

class _KuyenaHomePageState extends State<KuyenaHomePage> {
  late CalendarDate _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.diary.today;
  }

  void _selectToday() => setState(() => _selectedDate = widget.diary.today);

  void _selectDate(CalendarDate date) => setState(() => _selectedDate = date);

  void _openDiary({bool log = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PeriodHomePage(diary: widget.diary, openEntryOnLoad: log),
      ),
    );
  }

  void _showPreview({bool recommendations = false}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendations ? 'For you' : 'Designvorschau',
              style: HomeDesign.text(26),
            ),
            const SizedBox(height: 12),
            Text(
              recommendations
                  ? 'Für dich liegen noch keine persönlichen Empfehlungen vor. '
                        'Die Bewegungsideen auf der Startseite sind Beispiele.'
                  : '„3 Days“, Zyklusphase und Beschwerden auf dieser '
                        'Startseite sind Beispieldaten. Sie sind keine '
                        'Auswertung deiner gespeicherten Einträge.',
              style: HomeDesign.text(
                16,
                color: HomeDesign.ink,
                weight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: HomeDesign.red),
              onPressed: () => Navigator.pop(context),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopHero() => LayoutBuilder(
    builder: (context, constraints) {
      final scale = constraints.maxWidth / 412;
      return Stack(
        children: [
          Positioned(
            top: -60 * scale,
            left: 0,
            child: _HomeAsset(
              'header-background',
              width: 412.001 * scale,
              height: 435 * scale,
            ),
          ),
          Column(
            children: [
              SizedBox(height: 20 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 26 * scale),
                child: _DateToolbar(
                  scale: scale,
                  selectedDate: _selectedDate,
                  onToday: _selectToday,
                  showToday: false,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 26 * scale),
                child: CurvedDateSlider(
                  scale: scale,
                  selectedDate: _selectedDate,
                  onChanged: _selectDate,
                  showArrows: true,
                ),
              ),
              SizedBox(height: 12 * scale),
              _CycleRing(scale: scale, onTap: _showPreview),
              SizedBox(height: 24 * scale),
            ],
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: HomeDesign.palePink,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7F9),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return HomeDesktopLayout(
                selectedDate: _selectedDate,
                hero: _desktopHero(),
                information: _InformationCards(
                  scale: 1.1,
                  onPreview: _showPreview,
                  onMovement: () => _showPreview(recommendations: true),
                ),
                onToday: _selectToday,
                onCalendar: () => _openDiary(),
                onLog: () => _openDiary(log: true),
                onForYou: () => _showPreview(recommendations: true),
                onCycle: () => _openDiary(),
                onDemo: _showPreview,
              );
            }
            final wide = constraints.maxWidth > 600;
            final width = math.min(412.0, constraints.maxWidth);
            final height = wide
                ? math.min(917.0, constraints.maxHeight - 32)
                : constraints.maxHeight;
            final scale = width / 412;
            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kIsWeb || wide ? 30 : 0),
                  child: Material(
                    color: Colors.white,
                    child: Semantics(
                      label:
                          'Kuyena Startseite. Designvorschau mit Beispieldaten.',
                      container: true,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('home-scroll'),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 17 * scale,
                                    child: const ColoredBox(
                                      color: HomeDesign.red,
                                    ),
                                  ),
                                  Positioned(
                                    top: 16 * scale,
                                    left: 0,
                                    child: _HomeAsset(
                                      'header-background',
                                      width: 412.001 * scale,
                                      height: 435 * scale,
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      _StatusBar(scale: scale),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          26 * scale,
                                          5 * scale,
                                          26 * scale,
                                          0,
                                        ),
                                        child: SizedBox(
                                          height: 55 * scale,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Hey, girl!',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: HomeDesign.text(
                                                    40 * scale,
                                                    color: Colors.white,
                                                    height: 1.375,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: _showPreview,
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor: Colors.white
                                                      .withValues(alpha: 0.14),
                                                  minimumSize: const Size(
                                                    48,
                                                    32,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Demo',
                                                  style: HomeDesign.text(
                                                    12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 26 * scale,
                                        ),
                                        child: _DateToolbar(
                                          scale: scale,
                                          selectedDate: _selectedDate,
                                          onToday: _selectToday,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 26 * scale,
                                        ),
                                        child: CurvedDateSlider(
                                          scale: scale,
                                          selectedDate: _selectedDate,
                                          onChanged: _selectDate,
                                        ),
                                      ),
                                      SizedBox(height: 12 * scale),
                                      _CycleRing(
                                        scale: scale,
                                        onTap: _showPreview,
                                      ),
                                      SizedBox(height: 27 * scale),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 26 * scale,
                                        ),
                                        child: _InformationCards(
                                          scale: scale,
                                          onPreview: _showPreview,
                                          onMovement: () => _showPreview(
                                            recommendations: true,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 25 * scale),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _BottomNavigation(
                            scale: scale,
                            onHome: _selectToday,
                            onCalendar: () => _openDiary(),
                            onLog: () => _openDiary(log: true),
                            onForYou: () => _showPreview(recommendations: true),
                            onCycle: () => _openDiary(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeAsset extends StatelessWidget {
  const _HomeAsset(this.name, {required this.width, required this.height});

  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/home/$name.svg',
    key: ValueKey('home-asset-$name'),
    width: width,
    height: height,
    excludeFromSemantics: true,
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      // A real phone supplies its own clock and status icons.
      return SizedBox(
        height: math.max(36 * scale, MediaQuery.paddingOf(context).top),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: 36 * scale,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            26 * scale,
            12 * scale,
            26 * scale,
            2 * scale,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9:41',
                style: HomeDesign.text(13 * scale, color: Colors.white),
              ),
              Row(
                children: [
                  _HomeAsset(
                    'status-signal',
                    width: 16 * scale,
                    height: 16 * scale,
                  ),
                  SizedBox(width: 5 * scale),
                  _HomeAsset(
                    'status-wifi',
                    width: 16 * scale,
                    height: 16 * scale,
                  ),
                  SizedBox(width: 5 * scale),
                  _HomeAsset(
                    'status-battery',
                    width: 23 * scale,
                    height: 16 * scale,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateToolbar extends StatelessWidget {
  const _DateToolbar({
    required this.scale,
    required this.selectedDate,
    required this.onToday,
    this.showToday = true,
  });
  final double scale;
  final CalendarDate selectedDate;
  final VoidCallback onToday;
  final bool showToday;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28 * scale,
    child: Row(
      children: [
        Expanded(
          child: Text(
            MaterialLocalizations.of(
              context,
            ).formatMonthYear(selectedDate.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeDesign.text(13 * scale, color: Colors.white),
          ),
        ),
        if (showToday)
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: Size(48, 28 * scale),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Heute',
              style: HomeDesign.text(12 * scale, color: Colors.white),
            ),
          ),
      ],
    ),
  );
}

class _CycleRing extends StatelessWidget {
  const _CycleRing({required this.scale, required this.onTap});
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Designbeispiel: nächste Periode in drei Tagen. Details anzeigen.',
    excludeSemantics: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(200),
      onTap: onTap,
      child: SizedBox(
        width: 339 * scale,
        height: 339 * scale,
        child: Stack(
          children: [
            _HomeAsset(
              'cycle-background',
              width: 339 * scale,
              height: 339 * scale,
            ),
            Positioned(
              left: 27.05 * scale,
              top: 29 * scale,
              child: _HomeAsset(
                'cycle-arc',
                width: 287.342 * scale,
                height: 257.004 * scale,
              ),
            ),
            Positioned(
              top: 138 * scale,
              left: 0,
              right: 0,
              child: Text(
                'Next period in',
                textAlign: TextAlign.center,
                style: HomeDesign.text(15 * scale),
              ),
            ),
            Positioned(
              top: 155 * scale,
              left: 0,
              right: 0,
              child: Text(
                '3 Days',
                textAlign: TextAlign.center,
                style: HomeDesign.text(40 * scale, height: 1.375),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InformationCards extends StatelessWidget {
  const _InformationCards({
    required this.scale,
    required this.onPreview,
    required this.onMovement,
  });
  final double scale;
  final VoidCallback onPreview;
  final VoidCallback onMovement;

  Widget _card({
    required Widget child,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    color: color,
    borderRadius: BorderRadius.circular(26 * scale),
    child: InkWell(
      borderRadius: BorderRadius.circular(26 * scale),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          10 * scale,
          12 * scale,
          6 * scale,
        ),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _card(
              color: HomeDesign.palePink,
              onTap: onPreview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current phase', style: HomeDesign.text(12 * scale)),
                  SizedBox(height: 3 * scale),
                  Text(
                    'Luteal phase',
                    style: HomeDesign.text(22 * scale, height: 28 / 22),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: _card(
              color: HomeDesign.palePink,
              onTap: onPreview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possible symptoms',
                    style: HomeDesign.text(11 * scale, height: 16 / 11),
                  ),
                  SizedBox(height: 3 * scale),
                  Text(
                    'Cramps',
                    style: HomeDesign.text(22 * scale, height: 28 / 22),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 13 * scale),
      _card(
        color: HomeDesign.pink,
        onTap: onMovement,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested movement',
              style: HomeDesign.text(18 * scale, height: 23 / 18),
            ),
            SizedBox(height: 3 * scale),
            Text(
              'Walking · Swimming · Yoga',
              style: HomeDesign.text(15 * scale),
            ),
            SizedBox(height: 3 * scale),
            Text(
              'Choose what feels right today.',
              style: HomeDesign.text(12 * scale, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.scale,
    required this.onHome,
    required this.onCalendar,
    required this.onLog,
    required this.onForYou,
    required this.onCycle,
  });
  final double scale;
  final VoidCallback onHome;
  final VoidCallback onCalendar;
  final VoidCallback onLog;
  final VoidCallback onForYou;
  final VoidCallback onCycle;

  Widget _destination(
    String label,
    String icon,
    VoidCallback onTap, {
    bool active = false,
  }) => SizedBox(
    width: 68 * scale,
    child: Semantics(
      selected: active,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('home-nav-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52 * scale,
              height: 32 * scale,
              decoration: BoxDecoration(
                color: active ? HomeDesign.pink : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: _HomeAsset(icon, width: 22 * scale, height: 22 * scale),
            ),
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: HomeDesign.text(
                10.5 * scale,
                color: active ? HomeDesign.red : HomeDesign.muted,
                weight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extra = math.max(0.0, textScale - 1) * 20;
    final bottomInset = kIsWeb ? 0.0 : MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 144 * scale + extra + bottomInset,
      child: Stack(
        children: [
          Positioned(
            top: 45 * scale,
            left: 0,
            right: 0,
            bottom: 0,
            child: const ColoredBox(color: HomeDesign.palePink),
          ),
          Positioned(
            top: 54 * scale,
            left: 18 * scale,
            right: 18 * scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _destination('Home', 'home', onHome, active: true),
                _destination('Calendar', 'calendar', onCalendar),
                SizedBox(
                  width: 68 * scale,
                  child: Padding(
                    padding: EdgeInsets.only(top: 36 * scale),
                    child: Center(
                      child: InkWell(
                        onTap: onLog,
                        child: Text(
                          'Log',
                          style: HomeDesign.text(
                            10.5 * scale,
                            color: HomeDesign.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _destination('For you', 'compass', onForYou),
                _destination('Cycle', 'user', onCycle),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: (412 / 2 - 43) * scale,
            child: Semantics(
              button: true,
              label: 'Periode eintragen',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('home-log-button'),
                onTap: onLog,
                borderRadius: BorderRadius.circular(43),
                child: SizedBox(
                  width: 86 * scale,
                  height: 86 * scale,
                  child: Stack(
                    children: [
                      _HomeAsset(
                        'log-halo',
                        width: 86 * scale,
                        height: 86 * scale,
                      ),
                      Positioned(
                        left: 14 * scale,
                        top: 16 * scale,
                        child: _HomeAsset(
                          'log-button',
                          width: 57 * scale,
                          height: 57 * scale,
                        ),
                      ),
                      Positioned(
                        left: 27 * scale,
                        top: 29 * scale,
                        child: _HomeAsset(
                          'log-plus',
                          width: 31.5 * scale,
                          height: 31.5 * scale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (kIsWeb)
            Positioned(
              bottom: 21 * scale,
              left: (412 / 2 - 64) * scale,
              child: ExcludeSemantics(
                child: Container(
                  width: 128 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    color: HomeDesign.ink,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
