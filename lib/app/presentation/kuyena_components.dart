import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../home/presentation/home_design.dart';
import '../../periods/domain/calendar_date.dart';

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String monthLabel(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';
String fullDate(CalendarDate d) =>
    '${weekdayNames[d.value.weekday - 1]}, ${d.value.day} ${monthLabel(d.value)}';

class DesignAsset extends StatelessWidget {
  const DesignAsset(
    this.file, {
    super.key,
    required this.width,
    required this.height,
  });
  final String file;
  final double width, height;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/screens/$file',
    width: width,
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class DesignButton extends StatelessWidget {
  const DesignButton({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? HomeDesign.palePink : HomeDesign.red,
        foregroundColor: secondary ? HomeDesign.red : Colors.white,
        disabledBackgroundColor: HomeDesign.palePink,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(
        label,
        style: HomeDesign.text(
          16,
          color: secondary ? HomeDesign.red : Colors.white,
        ),
      ),
    ),
  );
}

class DateSummary extends StatelessWidget {
  const DateSummary({super.key, required this.date, required this.today});
  final CalendarDate date, today;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: HomeDesign.palePink,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Selected date',
              style: HomeDesign.text(
                11,
                color: HomeDesign.muted,
                weight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (date == today) Text('Today', style: HomeDesign.text(11)),
          ],
        ),
        const SizedBox(height: 3),
        Text(fullDate(date), style: HomeDesign.text(15, height: 1.3)),
      ],
    ),
  );
}

class KuyenaNavigation extends StatelessWidget {
  const KuyenaNavigation({
    super.key,
    required this.active,
    required this.onSelect,
    required this.onLog,
    this.datePicker = false,
  });
  final int active;
  final ValueChanged<int> onSelect;
  final VoidCallback onLog;
  final bool datePicker;
  static const labels = ['Home', 'Calendar', 'For you', 'Cycle'];
  static const inactive = ['3265f.svg', 'a2d7f.svg', '5ada5.svg', 'f8ec5.svg'];
  static const selected = ['e254f.svg', '6ad9e.svg', '94c62.svg', 'fae57.svg'];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = math.min(1.0, c.maxWidth / 412);
      Widget destination(int i) => SizedBox(
        width: 68 * s,
        child: Semantics(
          button: true,
          selected: active == i,
          child: InkWell(
            key: ValueKey('home-nav-${labels[i]}'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelect(i),
            child: Column(
              children: [
                Container(
                  width: 52 * s,
                  height: 32 * s,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active == i ? HomeDesign.pink : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: DesignAsset(
                    active == i ? selected[i] : inactive[i],
                    width: 22 * s,
                    height: 22 * s,
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  labels[i],
                  style: HomeDesign.text(
                    10.5 * s,
                    color: active == i ? HomeDesign.red : HomeDesign.muted,
                    weight: active == i ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return SizedBox(
        height: 144 * s,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 45 * s,
              bottom: 0,
              child: const ColoredBox(color: HomeDesign.palePink),
            ),
            Positioned(
              left: 18 * s,
              right: 18 * s,
              top: 54 * s,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  destination(0),
                  destination(1),
                  SizedBox(
                    width: 68 * s,
                    child: Padding(
                      padding: EdgeInsets.only(top: 36 * s),
                      child: InkWell(
                        onTap: onLog,
                        child: Text(
                          'Log',
                          textAlign: TextAlign.center,
                          style: HomeDesign.text(
                            10.5 * s,
                            color: HomeDesign.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  destination(2),
                  destination(3),
                ],
              ),
            ),
            Positioned(
              left: c.maxWidth / 2 - 43 * s,
              top: 0,
              child: Semantics(
                button: true,
                label: 'Log your day',
                child: InkWell(
                  key: const ValueKey('home-log-button'),
                  onTap: onLog,
                  borderRadius: BorderRadius.circular(43),
                  child: SizedBox(
                    width: 86 * s,
                    height: 86 * s,
                    child: Stack(
                      children: [
                        DesignAsset(
                          datePicker ? 'f1a37.svg' : '75d8d.svg',
                          width: 86 * s,
                          height: 86 * s,
                        ),
                        if (!datePicker)
                          Positioned(
                            left: 14 * s,
                            top: 16 * s,
                            child: DesignAsset(
                              'aa209.svg',
                              width: 57 * s,
                              height: 57 * s,
                            ),
                          ),
                        Positioned(
                          left: 27 * s,
                          top: 29 * s,
                          child: DesignAsset(
                            datePicker ? 'f7f8a.svg' : 'a4365.svg',
                            width: 31.5 * s,
                            height: 31.5 * s,
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
                bottom: 21 * s,
                left: c.maxWidth / 2 - 64 * s,
                child: Container(
                  width: 128 * s,
                  height: 4 * s,
                  decoration: BoxDecoration(
                    color: HomeDesign.ink,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class KuyenaSidebar extends StatelessWidget {
  const KuyenaSidebar({
    super.key,
    required this.active,
    required this.onSelect,
    required this.onLog,
  });
  final int active;
  final ValueChanged<int> onSelect;
  final VoidCallback onLog;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 1200 ? 192 : 224,
    child: ColoredBox(
      color: HomeDesign.palePink,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kuyena', style: HomeDesign.text(32)),
            const SizedBox(height: 6),
            Text(
              'Your cycle. Your pace.',
              style: HomeDesign.text(
                13,
                color: HomeDesign.muted,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 36),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: i == active ? HomeDesign.pink : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    key: ValueKey('home-nav-${KuyenaNavigation.labels[i]}'),
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          DesignAsset(
                            i == active
                                ? KuyenaNavigation.selected[i]
                                : KuyenaNavigation.inactive[i],
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Text(
                              KuyenaNavigation.labels[i],
                              style: HomeDesign.text(
                                16,
                                color: i == active
                                    ? HomeDesign.red
                                    : HomeDesign.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            DesignButton(
              key: const ValueKey('home-log-button'),
              label: '+  Log',
              onPressed: onLog,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A shared responsive frame; narrow screens retain the 412 px Figma layout.
class KuyenaPage extends StatelessWidget {
  const KuyenaPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onSelect,
    required this.onLog,
    required this.child,
    this.trailing,
    this.compactHeader = false,
    this.headerHeight,
    this.scroll = true,
    this.padding = const EdgeInsets.fromLTRB(26, 24, 26, 12),
    this.datePicker = false,
  });
  final String title, subtitle;
  final int active;
  final ValueChanged<int> onSelect;
  final VoidCallback onLog;
  final Widget child;
  final Widget? trailing;
  final bool compactHeader, scroll, datePicker;
  final double? headerHeight;
  final EdgeInsets padding;
  Widget _heading(bool desktop) {
    if (compactHeader) {
      return Container(
        color: HomeDesign.red,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: HomeDesign.text(
                      25,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
                if (trailing != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 32),
                    child: trailing!,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: HomeDesign.text(
                15,
                color: Colors.white,
                weight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: desktop ? 134 : 150,
      child: ColoredBox(
        color: HomeDesign.red,
        child: Stack(
          children: [
            if (!desktop)
              const Positioned(
                left: 26,
                right: 26,
                top: 12,
                child: DesignStatusBar(),
              ),
            Positioned(
              left: 26,
              right: 26,
              top: desktop ? 24 : 49,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: HomeDesign.text(40, color: Colors.white, height: 1.15),
                ),
              ),
            ),
            Positioned(
              left: 27,
              right: 26,
              top: desktop ? 82 : 96,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: HomeDesign.text(
                        15,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final desktop = c.maxWidth >= 900;
            Widget contents() => LayoutBuilder(
              builder: (context, inner) {
                final heading = _heading(desktop);
                final content = Container(
                  width: double.infinity,
                  constraints: scroll
                      ? BoxConstraints(
                          minHeight: math.max(
                            0,
                            inner.maxHeight -
                                (headerHeight ??
                                    (compactHeader
                                        ? 124
                                        : desktop
                                        ? 134
                                        : 150)),
                          ),
                        )
                      : null,
                  padding: padding,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: compactHeader
                        ? null
                        : const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: child,
                );
                final body = scroll
                    ? SingleChildScrollView(
                        child: Column(children: [heading, content]),
                      )
                    : Column(
                        children: [
                          heading,
                          Expanded(child: content),
                        ],
                      );
                return ColoredBox(color: HomeDesign.red, child: body);
              },
            );
            if (desktop) {
              return Row(
                children: [
                  KuyenaSidebar(
                    active: active,
                    onSelect: onSelect,
                    onLog: onLog,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: contents(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final width = math.min(412.0, c.maxWidth);
            return Center(
              child: SizedBox(
                width: width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kIsWeb ? 30 : 0),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Expanded(child: contents()),
                        KuyenaNavigation(
                          active: active,
                          onSelect: onSelect,
                          onLog: onLog,
                          datePicker: datePicker,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class DesignStatusBar extends StatelessWidget {
  const DesignStatusBar({super.key});
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      return const SizedBox(height: 22);
    }
    return Row(
      children: [
        Text('9:41', style: HomeDesign.text(13, color: Colors.white)),
        const Spacer(),
        const DesignAsset('5130b.svg', width: 16, height: 16),
        const SizedBox(width: 5),
        const DesignAsset('b616c.svg', width: 16, height: 16),
        const SizedBox(width: 5),
        const DesignAsset('12afe.svg', width: 23, height: 16),
      ],
    );
  }
}

Future<void> showDesignInfo(BuildContext context, String title, String text) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: HomeDesign.text(26)),
            const SizedBox(height: 16),
            Text(
              text,
              style: HomeDesign.text(
                16,
                color: HomeDesign.ink,
                weight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            DesignButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

void showDesignNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.sizeOf(context).width >= 900 ? 16 : 150,
      ),
      content: Text(message),
    ),
  );
}
