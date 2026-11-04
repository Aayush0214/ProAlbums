import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// "Custom color" (like the system gallery): a rainbow bar for the hue and a
/// box for how strong / light it is. [onChanged] runs live (the collage shows
/// it at once); X answers null (the caller puts the old colour back), ✓ the
/// colour.
Future<Color?> showCustomColorSheet(
  BuildContext context, {
  required Color initial,
  required ValueChanged<Color> onChanged,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    barrierColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) =>
        _CustomColorSheet(initial: initial, onChanged: onChanged),
  );
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({required this.initial, required this.onChanged});

  final Color initial;
  final ValueChanged<Color> onChanged;

  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);

  void _set(HSVColor color) {
    setState(() => _color = color);
    widget.onChanged(color.toColor());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    'Custom color',
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Done',
                  icon: const Icon(LucideIcons.check),
                  onPressed: () => Navigator.of(context).pop(_color.toColor()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _HueBar(
              hue: _color.hue,
              onChanged: (hue) => _set(_color.withHue(hue)),
            ),
            const SizedBox(height: 16),
            _ShadeBox(
              color: _color,
              onChanged: (saturation, value) =>
                  _set(_color.withSaturation(saturation).withValue(value)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rainbow bar: drag (or tap) to pick the hue.
class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void pick(Offset local) =>
            onChanged((local.dx / width).clamp(0.0, 1.0) * 360);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => pick(details.localPosition),
          onHorizontalDragUpdate: (details) => pick(details.localPosition),
          child: SizedBox(
            height: _height,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        for (var h = 0; h <= 360; h += 60)
                          HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (hue / 360 * width - _height / 2).clamp(
                    0.0,
                    width - _height,
                  ),
                  child: _Thumb(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    size: _height,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The box: left → right = more colour, top → bottom = darker.
class _ShadeBox extends StatelessWidget {
  const _ShadeBox({required this.color, required this.onChanged});

  final HSVColor color;
  final void Function(double saturation, double value) onChanged;

  static const double _height = 160;
  static const double _thumb = 22;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void pick(Offset local) => onChanged(
          (local.dx / width).clamp(0.0, 1.0),
          1 - (local.dy / _height).clamp(0.0, 1.0),
        );
        final pure = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => pick(details.localPosition),
          onPanUpdate: (details) => pick(details.localPosition),
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.mediaBadgeText, pure],
                        ),
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: color.saturation * width - _thumb / 2,
                  top: (1 - color.value) * _height - _thumb / 2,
                  child: _Thumb(color: color.toColor(), size: _thumb),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mediaBadgeText, width: 3),
        boxShadow: const [
          BoxShadow(color: AppColors.mediaScrimTop, blurRadius: 4),
        ],
      ),
    );
  }
}
