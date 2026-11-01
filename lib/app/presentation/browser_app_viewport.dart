import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../home/presentation/home_design.dart';

/// Keeps the phone layout as the first view when opening the browser demo.
class BrowserAppViewport extends StatefulWidget {
  const BrowserAppViewport({
    super.key,
    required this.child,
    this.enabled = kIsWeb,
  });

  final Widget child;
  final bool enabled;

  @override
  State<BrowserAppViewport> createState() => _BrowserAppViewportState();
}

class _BrowserAppViewportState extends State<BrowserAppViewport> {
  bool _desktop = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowDesktop = constraints.maxWidth >= 900;
        final showDesktop = canShowDesktop && _desktop;
        final appWidth = showDesktop
            ? constraints.maxWidth
            : math.min(412.0, constraints.maxWidth);

        return ColoredBox(
          color: HomeDesign.cycleRest,
          child: Stack(
            children: [
              // Keep the Navigator in the same place in the widget tree when
              // changing views or resizing, so open forms retain their drafts.
              Positioned.fill(
                top: canShowDesktop ? 56 : 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    key: const ValueKey('browser-app-viewport'),
                    width: appWidth,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: showDesktop
                            ? const []
                            : const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 24,
                                ),
                              ],
                      ),
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, appConstraints) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              size: Size(
                                appConstraints.maxWidth,
                                appConstraints.maxHeight,
                              ),
                            ),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Put controls after the Navigator so route semantics do not
              // hide them from screen readers when a page or dialog opens.
              if (canShowDesktop)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 56,
                  child: Material(
                    color: HomeDesign.cycleRest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const ValueKey('browser-view-toggle'),
                          onPressed: () => setState(() => _desktop = !_desktop),
                          icon: Icon(
                            showDesktop
                                ? Icons.smartphone_rounded
                                : Icons.desktop_windows_rounded,
                            size: 20,
                          ),
                          label: Text(
                            showDesktop ? 'Handyansicht' : 'Desktopansicht',
                            style: HomeDesign.text(14),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: HomeDesign.red,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
