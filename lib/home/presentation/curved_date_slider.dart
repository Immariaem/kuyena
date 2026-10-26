import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../periods/domain/calendar_date.dart';
import 'home_design.dart';

/// Five consecutive civil dates. The selected date sits at the top of the arc.
class CurvedDateSlider extends StatefulWidget {
  const CurvedDateSlider({
    super.key,
    required this.selectedDate,
    required this.onChanged,
    this.scale = 1,
    this.showArrows = false,
  });

  final CalendarDate selectedDate;
  final ValueChanged<CalendarDate> onChanged;
  final double scale;
  final bool showArrows;

  @override
  State<CurvedDateSlider> createState() => _CurvedDateSliderState();
}

class _CurvedDateSliderState extends State<CurvedDateSlider> {
  static final _first = DateTime.utc(1);
  static final _dayCount =
      DateTime.utc(9999, 12, 31).difference(_first).inDays + 1;
  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  late final PageController _controller;
  final _focus = FocusNode(debugLabel: 'Datumsrad');
  double _wheelDelta = 0;

  int _index(CalendarDate date) => DateTime.utc(
    date.value.year,
    date.value.month,
    date.value.day,
  ).difference(_first).inDays;

  CalendarDate _dateAt(int index) =>
      CalendarDate.fromDateTime(_first.add(Duration(days: index)));

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _index(widget.selectedDate),
      viewportFraction: 1 / 5,
    );
  }

  @override
  void didUpdateWidget(covariant CurvedDateSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate &&
        _controller.hasClients) {
      final index = _index(widget.selectedDate);
      final current = _controller.page ?? index.toDouble();
      if (current.round() != index) {
        if ((current - index).abs() > 14) {
          _controller.jumpToPage(index);
        } else {
          _controller.animateToPage(
            index,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _focus.requestFocus();
    _controller.animateToPage(
      index.clamp(0, _dayCount - 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _step(int direction) => _goTo(
    (_controller.page ?? _index(widget.selectedDate).toDouble()).round() +
        direction,
  );

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Resolve once, so a wheel gesture does not also scroll the whole page.
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      final scroll = signal as PointerScrollEvent;
      final delta = scroll.scrollDelta.dx.abs() > scroll.scrollDelta.dy.abs()
          ? scroll.scrollDelta.dx
          : scroll.scrollDelta.dy;
      _wheelDelta += delta;
      if (_wheelDelta.abs() >= 24) {
        final direction = _wheelDelta.isNegative ? -1 : 1;
        _wheelDelta = 0;
        _step(direction);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final localizations = MaterialLocalizations.of(context);
    final selectedIndex = _index(widget.selectedDate);
    return Semantics(
      label: 'Datum auswählen',
      value: localizations.formatFullDate(widget.selectedDate.value),
      increasedValue: selectedIndex < _dayCount - 1
          ? localizations.formatFullDate(_dateAt(selectedIndex + 1).value)
          : null,
      decreasedValue: selectedIndex > 0
          ? localizations.formatFullDate(_dateAt(selectedIndex - 1).value)
          : null,
      onIncrease: selectedIndex < _dayCount - 1 ? () => _step(1) : null,
      onDecrease: selectedIndex > 0 ? () => _step(-1) : null,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: SizedBox(
          key: const ValueKey('curved-date-slider'),
          height: 106 * scale,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showArrows)
                Padding(
                  padding: EdgeInsets.only(top: 22 * scale),
                  child: IconButton(
                    tooltip: 'Vorheriger Tag',
                    onPressed: () => _step(-1),
                    color: Colors.white,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _focus.requestFocus(),
                  onPointerSignal: _onPointerSignal,
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                      scrollbars: false,
                    ),
                    child: _FiveDayViewport(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _dayCount,
                        clipBehavior: Clip.none,
                        physics: const PageScrollPhysics(),
                        onPageChanged: (index) =>
                            widget.onChanged(_dateAt(index)),
                        itemBuilder: (context, index) {
                          final date = _dateAt(index);
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final position = _controller.hasClients
                                  ? (_controller.page ??
                                        _controller.initialPage.toDouble())
                                  : _controller.initialPage.toDouble();
                              final distance = index - position;
                              final strength = (1 - distance.abs()).clamp(
                                0.0,
                                1.0,
                              );
                              final drop =
                                  math.pow(distance.abs().clamp(0.0, 3.0), 2) *
                                  8 *
                                  scale;
                              return Align(
                                alignment: Alignment.topCenter,
                                child: Transform.translate(
                                  offset: Offset(0, drop.toDouble()),
                                  child: Semantics(
                                    button: true,
                                    selected: distance.abs() < 0.5,
                                    label: localizations.formatFullDate(
                                      date.value,
                                    ),
                                    excludeSemantics: true,
                                    child: Material(
                                      key: ValueKey('date-${date.iso}'),
                                      color: Color.lerp(
                                        HomeDesign.palePink.withValues(
                                          alpha: 0,
                                        ),
                                        HomeDesign.palePink,
                                        strength,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        30 * scale,
                                      ),
                                      child: InkWell(
                                        onTap: () => _goTo(index),
                                        borderRadius: BorderRadius.circular(
                                          30 * scale,
                                        ),
                                        child: SizedBox(
                                          width: 46 * scale,
                                          height: 76 * scale,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 11 * scale,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _weekdays[date
                                                            .value
                                                            .weekday -
                                                        1],
                                                    maxLines: 1,
                                                    style: HomeDesign.text(
                                                      15 * scale,
                                                      color: Color.lerp(
                                                        Colors.white,
                                                        HomeDesign.red,
                                                        strength,
                                                      )!,
                                                    ),
                                                  ),
                                                  Text(
                                                    date.value.day
                                                        .toString()
                                                        .padLeft(2, '0'),
                                                    maxLines: 1,
                                                    style: HomeDesign.text(
                                                      25 * scale,
                                                      color: Color.lerp(
                                                        Colors.white,
                                                        HomeDesign.red,
                                                        strength,
                                                      )!,
                                                      height: 1.36,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showArrows)
                Padding(
                  padding: EdgeInsets.only(top: 22 * scale),
                  child: IconButton(
                    tooltip: 'Nächster Tag',
                    onPressed: () => _step(1),
                    color: Colors.white,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiveDayViewport extends StatelessWidget {
  const _FiveDayViewport({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        // Whole-pixel day widths avoid accumulated scroll rounding errors.
        width: (constraints.maxWidth / 5).floorToDouble() * 5,
        child: child,
      ),
    ),
  );
}
