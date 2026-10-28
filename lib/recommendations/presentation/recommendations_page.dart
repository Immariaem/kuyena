import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({
    super.key,
    required this.onSelect,
    required this.onLog,
  });
  final ValueChanged<int> onSelect;
  final VoidCallback onLog;
  static const cards = [
    ('Stretching', 'ef7b0.png'),
    ('Walks', '46ad5.png'),
    ('Soup', '57e5f.png'),
    ('Oats', '186d9.png'),
  ];
  void _open(
    BuildContext context,
    (String, String) card,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(
                'assets/screens/${card.$2}',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(card.$1, style: HomeDesign.text(26)),
          const SizedBox(height: 12),
          Text(
            'A general ${cards.indexOf(card) < 2 ? 'movement' : 'food'} idea to explore at your own pace. This suggestion is not based on a detected cycle phase.',
            style: HomeDesign.text(
              16,
              color: HomeDesign.ink,
              weight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'General ideas, not medical advice. Choose what feels right for you.',
            style: HomeDesign.text(13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          DesignButton(label: 'Close', onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
  Widget _card(BuildContext context, (String, String) c, double size) =>
      Semantics(
        button: true,
        label: c.$1,
        child: Material(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('recommendation-${c.$1}'),
            onTap: () => _open(context, c),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/screens/${c.$2}',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    width: size * 235 / 220,
                    height: size * 226 / 220,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(.226, -.974),
                            end: Alignment(-.226, .974),
                            colors: [Colors.transparent, HomeDesign.red],
                            stops: [.32297, .78797],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              c.$1,
                              style: HomeDesign.text(
                                14,
                                color: Colors.white,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  Widget _section(
    BuildContext context,
    String title,
    List<(String, String)> items,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: HomeDesign.text(22)),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, c) {
          final desktop = MediaQuery.sizeOf(context).width >= 900;
          final size = desktop
              ? ((c.maxWidth - 12) / 2).clamp(180.0, 300.0)
              : 220.0;
          return ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SizedBox(
              height: size,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _card(context, items[i], size),
              ),
            ),
          );
        },
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => KuyenaPage(
    title: 'Recommendations',
    subtitle: 'Ideas for your cycle phase.',
    active: 2,
    onSelect: onSelect,
    onLog: onLog,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, 'Movement', cards.take(2).toList()),
        const SizedBox(height: 14),
        _section(context, 'Food', cards.skip(2).toList()),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DesignAsset('e484e.svg', width: 20, height: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'General ideas, not medical advice. Choose what feels right for you.',
                  style: HomeDesign.text(
                    13,
                    weight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
