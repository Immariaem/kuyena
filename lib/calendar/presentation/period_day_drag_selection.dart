import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../periods/domain/calendar_date.dart';

/// Mouse/pen drag selects directly. Touch waits briefly so normal vertical
/// scrolling can win the gesture before a range selection begins.
class PeriodDayDragSelection extends StatefulWidget {
  const PeriodDayDragSelection({
    super.key,
    required this.month,
    required this.today,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });
  final DateTime month;
  final CalendarDate today;
  final ValueChanged<CalendarDate> onStart, onUpdate;
  final VoidCallback onEnd, onCancel;
  final Widget child;
  @override
  State<PeriodDayDragSelection> createState() => _PeriodDayDragSelectionState();
}

class _PeriodDayDragSelectionState extends State<PeriodDayDragSelection> {
  final _bodyKey = GlobalKey();
  CalendarDate? _down;
  bool _active = false;
  int? _pointer;

  CalendarDate? _dateAt(Offset position, {bool starting = false}) {
    final box = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(position);
    if (!(Offset.zero & box.size).contains(local)) return null;
    final column = (local.dx / (box.size.width / 7)).floor();
    final row = (local.dy / 44).floor();
    final offset =
        DateTime(widget.month.year, widget.month.month, 1).weekday - 1;
    final day = row * 7 + column - offset + 1;
    final count = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    if (day < 1 || day > count) return null;
    final date = CalendarDate(widget.month.year, widget.month.month, day);
    if (date.compareTo(widget.today) > 0) {
      return starting ? null : widget.today;
    }
    return date;
  }

  bool _canStart(Offset position) => _dateAt(position, starting: true) != null;
  void _start(CalendarDate? date, Offset position) {
    if (date == null || _active) return;
    _active = true;
    Tooltip.dismissAllToolTips();
    widget.onStart(date);
    _update(position);
  }

  void _update(Offset position) {
    if (!_active) return;
    final date = _dateAt(position);
    if (date != null) widget.onUpdate(date);
  }

  void _end() {
    _down = null;
    if (!_active) return;
    _active = false;
    widget.onEnd();
  }

  void _cancel() {
    _down = null;
    if (!_active) return;
    _active = false;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_pointer == null &&
          event.buttons == kPrimaryButton &&
          _canStart(event.position)) {
        _pointer = event.pointer;
      }
    },
    onPointerUp: (event) {
      if (event.pointer == _pointer) _pointer = null;
    },
    onPointerCancel: (event) {
      if (event.pointer == _pointer) {
        _pointer = null;
        _cancel();
      }
    },
    child: RawGestureDetector(
      excludeFromSemantics: true,
      gestures: {
        _PeriodPanRecognizer:
            GestureRecognizerFactoryWithHandlers<_PeriodPanRecognizer>(
              () => _PeriodPanRecognizer(),
              (recognizer) {
                recognizer.canStart = _canStart;
                recognizer.onDown = (details) {
                  _down = _dateAt(details.globalPosition, starting: true);
                };
                recognizer.onStart = (details) {
                  _start(_down, details.globalPosition);
                };
                recognizer.onUpdate = (details) {
                  _update(details.globalPosition);
                };
                recognizer.onEnd = (_) {
                  _end();
                };
                recognizer.onCancel = _cancel;
              },
            ),
        _PeriodHoldRecognizer:
            GestureRecognizerFactoryWithHandlers<_PeriodHoldRecognizer>(
              () => _PeriodHoldRecognizer(),
              (recognizer) {
                recognizer.canStart = _canStart;
                recognizer.onLongPressStart = (details) {
                  _start(
                    _dateAt(details.globalPosition, starting: true),
                    details.globalPosition,
                  );
                };
                recognizer.onLongPressMoveUpdate = (details) {
                  _update(details.globalPosition);
                };
                recognizer.onLongPressEnd = (details) {
                  _update(details.globalPosition);
                  _end();
                };
                recognizer.onLongPressCancel = _cancel;
              },
            ),
      },
      child: SizedBox(key: _bodyKey, child: widget.child),
    ),
  );
}

class _PeriodPanRecognizer extends PanGestureRecognizer {
  _PeriodPanRecognizer()
    : super(
        supportedDevices: const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );
  late bool Function(Offset) canStart;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event is PointerDownEvent &&
      canStart(event.position) &&
      super.isPointerAllowed(event);
}

class _PeriodHoldRecognizer extends LongPressGestureRecognizer {
  _PeriodHoldRecognizer()
    : super(
        duration: const Duration(milliseconds: 250),
        supportedDevices: const {PointerDeviceKind.touch},
      );
  late bool Function(Offset) canStart;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      canStart(event.position) && super.isPointerAllowed(event);
}
